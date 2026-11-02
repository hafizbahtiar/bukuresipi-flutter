import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/db_time.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<List<Place>> list() => _call(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/places')).data!;
    final places = [
      for (final j in data['places'] as List)
        placeFromJson(j as Map<String, dynamic>),
    ];
    return places..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<void> updateNote(String id, String? note) => _call(() async {
    final trimmed = note?.trim();
    await _dio.patch<void>(
      '/places/$id',
      data: {'note': trimmed == null || trimmed.isEmpty ? null : trimmed},
    );
  });

  @override
  Future<void> setPin(String branchId, double lat, double lng) => _call(
    () => _dio.put<void>(
      '/places/branches/$branchId/pin',
      data: {'lat': lat, 'lng': lng},
    ),
  );

  @override
  Future<bool> locate(String branchId) => _call(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/places/branches/$branchId/locate',
      // The server may search the web and ask the AI: longer than the usual 30 s.
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    return res.data!['found'] == true;
  });

  @override
  Future<({int merged, int removed})> tidyBranches(String restaurantId) =>
      _call(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/places/restaurants/$restaurantId/tidy',
          // Clef compares the branches one by one on the server.
          options: Options(receiveTimeout: const Duration(seconds: 90)),
        );
        return (
          merged: res.data!['merged'] as int,
          removed: res.data!['removed'] as int,
        );
      });

  @override
  Future<void> deleteBranch(String branchId) =>
      _call(() => _dio.delete<void>('/places/branches/$branchId'));

  @override
  Future<void> remove(String id) =>
      _call(() => _dio.delete<void>('/places/$id'));
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

Place placeFromJson(Map<String, dynamic> j) {
  final r = j['restaurant'] as Map<String, dynamic>;
  return Place(
    id: j['id'] as String,
    note: j['note'] as String?,
    createdAt: dbTime(j['createdAt'] as String),
    branchId: j['branchId'] as String?,
    restaurant: PlaceRestaurant(
      id: r['id'] as String,
      name: r['name'] as String,
      cuisine: r['cuisine'] as String?,
      halalClaim: r['halalClaim'] as String?,
      halalQuote: r['halalQuote'] as String?,
      halalSourceUrl: r['halalSourceUrl'] as String?,
    ),
    branches: [
      for (final b in (j['branches'] as List).cast<Map<String, dynamic>>())
        Branch(
          id: b['id'] as String,
          label: b['label'] as String?,
          address: b['address'] as String?,
          city: b['city'] as String?,
          state: b['state'] as String?,
          lat: _num(b['lat']),
          lng: _num(b['lng']),
          pinSource: b['pinSource'] as String?,
        ),
    ],
  );
}
