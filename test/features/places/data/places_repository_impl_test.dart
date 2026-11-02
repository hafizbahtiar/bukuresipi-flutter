import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/places/data/places_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';
import '../places_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  PlacesRepositoryImpl make((int, Object?) Function(RequestOptions) answer) {
    adapter = FakeAdapter(answer);
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: adapter,
    );
    return PlacesRepositoryImpl(api.dio);
  }

  test(
    'list reads places, newest first, with the saved branch and its pin',
    () async {
      final older = {
        ...placeJson,
        'id': 'p-0',
        'createdAt': '2026-11-01 08:00:00',
      };
      final repo = make(
        (_) => (
          200,
          {
            'places': [older, placeJson],
          },
        ),
      );
      final places = await repo.list();
      expect(places.map((p) => p.id), ['p-1', 'p-0']);
      final p = places.first;
      expect(p.restaurant.name, 'Nasi Kandar Pelita');
      expect(p.savedBranch?.label, 'Pelita Jalan Ampang');
      expect(p.pins.map((b) => b.id), [
        'b-2',
      ], reason: 'a branch without lat/lng gets no pin');
      expect(p.createdAt.isUtc, isTrue);
    },
  );

  test('note: PATCH with null for empty; remove: DELETE', () async {
    final repo = make((_) => (200, {'ok': true}));
    await repo.updateNote('p-1', '  ');
    await repo.remove('p-1');
    expect(adapter.requests[0].method, 'PATCH');
    expect(adapter.requests[0].path, '/places/p-1');
    expect(adapter.requests[0].data, {'note': null});
    expect(
      [adapter.requests[1].method, adapter.requests[1].path],
      ['DELETE', '/places/p-1'],
    );
  });
}
