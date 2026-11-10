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
              restaurantId: place['restaurantId'] as String,
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
          ),
      ],
      charges: _charges(j['charges'] as Map<String, dynamic>?),
      hasImage: j['hasImage'] as bool? ?? false,
    );
  }

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
  }) => apiCall(
    () async => _receipt(
      (await _dio.post<Map<String, dynamic>>(
        '/receipts/$id/confirm',
        data: {
          'totalSen': totalSen,
          'visitedAt': visitedAt.toUtc().toIso8601String(),
          'branchId': ?branchId,
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
            restaurantId: p['restaurantId'] as String,
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
