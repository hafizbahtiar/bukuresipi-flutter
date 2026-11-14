import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/receipt.dart';
import '../domain/receipts_repository.dart';

class ReceiptsRepositoryImpl implements ReceiptsRepository {
  ReceiptsRepositoryImpl(this._dio);

  final Dio _dio;

  static Receipt _receipt(Map<String, dynamic> j) {
    final place = j['place'] as Map<String, dynamic>?;
    final visited = j['visitedAt'] as String?;
    return Receipt(
      id: j['id'] as String,
      status: j['status'] as String,
      shop: j['shop'] as String?,
      place: place == null
          ? null
          : (
              placeId: place['placeId'] as String,
              branchId: place['branchId'] as String?,
              name: place['name'] as String,
            ),
      visitedAt: visited == null ? null : DateTime.parse(visited).toLocal(),
      totalSen: j['totalSen'] as int?,
      gaps: ((j['gaps'] as List?) ?? const []).cast<String>(),
      items: [
        for (final i in (j['items'] as List?) ?? const [])
          (
            name: i['name'] as String,
            quantity: (i['quantity'] as num?)?.toDouble(),
            amountSen: i['amountSen'] as int?,
            kcal: (i['kcal'] as num?)?.round(),
            kcalSource: i['kcalSource'] as String?,
            eaten: (i['eaten'] as num?)?.toDouble() ?? 0,
          ),
      ],
      charges: _charges(j['charges'] as Map<String, dynamic>?),
      hasImage: j['hasImage'] as bool? ?? false,
      reason: j['reason'] as String?,
      eatenKcal: (j['eatenKcal'] as num?)?.round() ?? 0,
      hasEstimate: j['hasEstimate'] as bool? ?? false,
      unknownEaten: (j['unknownEaten'] as num?)?.toDouble() ?? 0,
      caloriesPending: j['caloriesPending'] as bool? ?? false,
      hasSplit: j['hasSplit'] as bool? ?? false,
    );
  }

  @override
  Future<void> setEaten(String id, int position, double eaten) => apiCall(
    () =>
        _dio.put<void>('/receipts/$id/items/$position', data: {'eaten': eaten}),
  );

  @override
  Future<DailyCalories> calories() => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/receipts/calories'))
        .data!;
    return (
      eatenKcal: (j['eatenKcal'] as num).round(),
      target: j['target'] as int?,
      hasEstimate: j['hasEstimate'] as bool,
      unknownEaten: (j['unknownEaten'] as num).toDouble(),
      macros: _macros(j['macros']),
      meals: [
        for (final m in (j['meals'] as List?) ?? const [])
          (
            id: m['id'] as String,
            eatenAt: DateTime.parse(m['eatenAt'] as String).toLocal(),
            eatenKcal: (m['eatenKcal'] as num).round(),
            macros: _macros(m['macros']),
            items: [
              for (final i in (m['items'] as List?) ?? const []) _mealItem(i),
            ],
          ),
      ],
      receipts: [
        for (final r in (j['receipts'] as List?) ?? const [])
          (
            id: r['id'] as String,
            shop: r['shop'] as String?,
            visitedAt: DateTime.parse(r['visitedAt'] as String).toLocal(),
            eatenKcal: (r['eatenKcal'] as num).round(),
            items: [
              for (final i in (r['items'] as List?) ?? const [])
                (
                  name: i['name'] as String,
                  eaten: (i['eaten'] as num).toDouble(),
                  kcal: (i['kcal'] as num?)?.round(),
                  kcalSource: i['kcalSource'] as String?,
                ),
            ],
          ),
      ],
    );
  });

  static Macros? _macros(Object? j) => j is Map
      ? (
          carbsG: (j['carbsG'] as num).toDouble(),
          proteinG: (j['proteinG'] as num).toDouble(),
          fatG: (j['fatG'] as num).toDouble(),
        )
      : null;

  static MealItem _mealItem(dynamic i) => (
    name: i['name'] as String,
    eaten: (i['eaten'] as num).toDouble(),
    kcal: (i['kcal'] as num?)?.round(),
    kcalSource: i['kcalSource'] as String?,
    carbsG: (i['carbsG'] as num?)?.toDouble(),
    proteinG: (i['proteinG'] as num?)?.toDouble(),
    fatG: (i['fatG'] as num?)?.toDouble(),
  );

  @override
  Future<List<MealItem>> estimateMeal(String path) => apiCall(() async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        path,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final j = (await _dio.post<Map<String, dynamic>>(
      '/meals/estimate',
      data: form,
      // One AI call over a photo while the user waits: past the usual 30 s on a slow day.
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    )).data!;
    return [for (final i in (j['items'] as List?) ?? const []) _mealItem(i)];
  });

  @override
  Future<void> saveMeal(DateTime eatenAt, List<MealItem> items) => apiCall(
    () => _dio.post<void>(
      '/meals',
      data: {
        'eatenAt': eatenAt.toUtc().toIso8601String(),
        'items': [
          for (final i in items) {'name': i.name, 'servings': i.eaten},
        ],
      },
    ),
  );

  @override
  Future<void> removeMeal(String id) =>
      apiCall(() => _dio.delete<void>('/meals/$id'));

  @override
  Future<CalorieDays> calorieDays({int days = 30}) => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>(
      '/receipts/calories/days',
      queryParameters: {'days': days},
    )).data!;
    return CalorieDays(
      days: [
        for (final d in (j['days'] as List).cast<Map<String, dynamic>>())
          (
            date: DateTime.parse(d['date'] as String),
            eatenKcal: (d['eatenKcal'] as num).round(),
            hasEstimate: d['hasEstimate'] as bool,
            unknownEaten: (d['unknownEaten'] as num).toDouble(),
          ),
      ],
      target: j['target'] as int?,
    );
  });

  @override
  Future<ReceiptSplit> split(String id) => apiCall(
    () async => _split(
      (await _dio.get<Map<String, dynamic>>('/receipts/$id/split')).data!,
    ),
  );

  @override
  Future<ReceiptSplit> saveSplit(
    String id, {
    required List<SplitPerson> people,
    required List<SplitPortion> portions,
  }) => apiCall(
    () async => _split(
      (await _dio.put<Map<String, dynamic>>(
        '/receipts/$id/split',
        data: {
          'people': [
            for (final p in people) {'name': p.name, 'paid': p.paid},
          ],
          'portions': [
            for (final p in portions)
              {
                'position': p.position,
                'person': p.person,
                'quantity': p.quantity,
              },
          ],
        },
      )).data!,
    ),
  );

  @override
  Future<void> clearSplit(String id) =>
      apiCall(() => _dio.delete<void>('/receipts/$id/split'));

  static ReceiptSplit _split(Map<String, dynamic> j) => ReceiptSplit(
    people: [
      for (final p in (j['people'] as List?) ?? const [])
        (name: p['name'] as String, paid: p['paid'] as bool? ?? false),
    ],
    portions: [
      for (final p in (j['portions'] as List?) ?? const [])
        (
          position: p['position'] as int,
          person: p['person'] as int,
          quantity: (p['quantity'] as num).toDouble(),
        ),
    ],
    shares: [
      for (final s in (j['shares'] as List?) ?? const [])
        (
          person: s['person'] as int,
          amountSen: s['amountSen'] as int,
          lines: ((s['lines'] as List?) ?? const []).cast<String>(),
        ),
    ],
    totalSen: j['totalSen'] as int?,
  );

  @override
  Future<String> upload(String path) => apiCall(() async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        path,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    return (await _dio.post<Map<String, dynamic>>(
          '/receipts',
          data: form,
        )).data!['id']
        as String;
  });

  @override
  Future<Receipt> get(String id) => apiCall(
    () async =>
        _receipt((await _dio.get<Map<String, dynamic>>('/receipts/$id')).data!),
  );

  @override
  Future<({List<Receipt> items, String? next})> list({String? cursor}) =>
      apiCall(() async {
        final j = (await _dio.get<Map<String, dynamic>>(
          '/receipts',
          queryParameters: {'cursor': ?cursor},
        )).data!;
        return (
          items: [
            for (final r in (j['items'] as List).cast<Map<String, dynamic>>())
              _receipt(r),
          ],
          next: j['next'] as String?,
        );
      });

  @override
  Future<Receipt> confirm(
    String id, {
    required int totalSen,
    required DateTime visitedAt,
    String? branchId,
    bool update = false,
  }) => apiCall(
    () async => _receipt(
      (await _dio.post<Map<String, dynamic>>(
        '/receipts/$id/confirm',
        data: {
          'totalSen': totalSen,
          'visitedAt': visitedAt.toUtc().toIso8601String(),
          'branchId': ?branchId,
          if (update) 'update': true,
        },
      )).data!,
    ),
  );

  @override
  Future<void> remove(String id) =>
      apiCall(() => _dio.delete<void>('/receipts/$id'));

  @override
  Future<Uint8List?> image(String id) => apiCall(() async {
    final res = await _dio.get<List<int>>(
      '/receipts/$id/image',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s == 200 || s == 404,
      ),
    );
    return res.statusCode == 200 ? Uint8List.fromList(res.data!) : null;
  });

  @override
  Future<ReceiptStats> stats({int months = 12}) => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>(
      '/receipts/stats',
      queryParameters: {'months': months},
    )).data!;
    return ReceiptStats(
      totalSen: j['totalSen'] as int,
      visits: j['visits'] as int,
      months: [
        for (final m in (j['months'] as List).cast<Map<String, dynamic>>())
          (
            month: m['month'] as String,
            visits: m['visits'] as int,
            totalSen: m['totalSen'] as int,
          ),
      ],
      places: [
        for (final p in (j['places'] as List).cast<Map<String, dynamic>>())
          (
            placeId: p['placeId'] as String,
            name: p['name'] as String,
            visits: p['visits'] as int,
            totalSen: p['totalSen'] as int,
          ),
      ],
    );
  });
}

List<ReceiptCharge> _charges(Map<String, dynamic>? c) {
  if (c == null) return const [];
  ReceiptCharge? one(String kind) => c['${kind}Sen'] is int
      ? (kind: kind, name: null, amountSen: c['${kind}Sen'] as int)
      : null;
  return [
    for (final k in ['subtotal', 'discount', 'service', 'tax']) ?one(k),
    for (final o in (c['other'] as List?) ?? const [])
      (
        kind: 'other',
        name: o['name'] as String,
        amountSen: o['amountSen'] as int,
      ),
    ?one('rounding'),
  ];
}
