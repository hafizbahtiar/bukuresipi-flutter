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
      expect(p.sourceUrl, 'https://www.tiktok.com/@makan/video/1');
      expect(p.savedBranch?.label, 'Pelita Jalan Ampang');
      expect(p.pins.map((b) => b.id), [
        'b-2',
      ], reason: 'a branch without lat/lng gets no pin');
      expect(p.createdAt.isUtc, isTrue);
    },
  );

  test('nearby sends the point and radius, and reads the branches', () async {
    final repo = make(
      (o) => o.path == '/places/nearby'
          ? (
              200,
              {
                'branches': [nearbyBranchJson],
              },
            )
          : (200, {}),
    );
    final rows = await repo.nearby(3.15, 101.71, 5);
    expect(adapter.requests.single.path, '/places/nearby');
    expect(adapter.requests.single.queryParameters, {
      'lat': 3.15,
      'lng': 101.71,
      'km': 5.0,
    });
    expect(rows.single.branchId, 'b-1');
    expect(rows.single.distanceM, 2400);
    expect(rows.single.saved, isFalse);
  });

  test('saveBranch POSTs the id and reads the place', () async {
    final repo = make((_) => (200, placeJson));
    final saved = await repo.saveBranch('b-2');
    expect(
      [
        adapter.requests.single.method,
        adapter.requests.single.path,
        adapter.requests.single.data,
      ],
      [
        'POST',
        '/places',
        {'branchId': 'b-2'},
      ],
    );
    expect(saved.restaurant.name, 'Nasi Kandar Pelita');
    expect(saved.branchId, 'b-2');
  });

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

  test(
    'pins: PUT the user pin, POST find location, DELETE a branch (owner)',
    () async {
      final repo = make(
        (o) =>
            o.path.endsWith('/locate') ? (200, {'found': true}) : (204, null),
      );
      await repo.setPin('b-1', 3.2, 101.69);
      expect(await repo.locate('b-1'), isTrue);
      await repo.deleteBranch('b-1');
      expect(
        [for (final r in adapter.requests) '${r.method} ${r.path}'],
        [
          'PUT /places/branches/b-1/pin',
          'POST /places/branches/b-1/locate',
          'DELETE /places/branches/b-1',
        ],
      );
      expect(adapter.requests.first.data, {'lat': 3.2, 'lng': 101.69});
      // The server may search the web and ask the AI: longer than the usual 30 s wait.
      expect(adapter.requests[1].receiveTimeout, const Duration(seconds: 90));
    },
  );

  test('one unreadable row does not take the whole list down', () async {
    final repo = make(
      (_) => (
        200,
        {
          'places': [
            placeJson,
            {'id': 'broken'},
          ],
        },
      ),
    );
    expect((await repo.list()).map((p) => p.id), ['p-1']);
  });

  test('a branch pinned by hand says so', () async {
    final repo = make(
      (_) => (
        200,
        {
          'places': [placeJson],
        },
      ),
    );
    final b = (await repo.list()).single.branches.last;
    expect([b.pinSource, b.pinnedByUser], ['user', isTrue]);
  });

  test('owner AI draft: POST and parse the branch suggestion', () async {
    final repo = make(
      (_) => (
        200,
        {
          'draft': {
            'label': 'AI Branch',
            'address': 'Jalan AI',
            'city': 'Bangi',
            'state': 'Selangor',
            'lat': 2.99,
            'lng': 101.79,
          },
          'sources': ['nominatim'],
          'aiUsed': true,
          'changed': true,
          'summary': 'Cleaned from the map.',
          'warnings': <String>[],
        },
      ),
    );
    final s = await repo.suggestBranch('b-1');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/places/branches/b-1/suggest');
    expect(
      adapter.requests.single.receiveTimeout,
      const Duration(seconds: 120),
    );
    expect(s.draft.label, 'AI Branch');
    expect(s.draft.lat, 2.99);
    expect(s.sources, ['nominatim']);
    expect(s.aiUsed, true);
    expect(s.changed, true);
  });

  test('owner branch edit: PATCH text and optional coordinates', () async {
    final repo = make((_) => (200, {}));
    await repo.updateBranch(
      'b-1',
      label: 'Kedai Baru',
      address: null,
      city: 'Bangi',
      state: null,
      lat: 2.99,
      lng: 101.79,
    );
    final request = adapter.requests.single;
    expect([request.method, request.path], ['PATCH', '/places/branches/b-1']);
    expect(request.data, {
      'label': 'Kedai Baru',
      'address': null,
      'city': 'Bangi',
      'state': null,
      'lat': 2.99,
      'lng': 101.79,
      'scope': 'self',
    });
  });

  test(
    'Check branches: POST the restaurant, read what was merged and removed',
    () async {
      final repo = make((_) => (200, {'merged': 2, 'removed': 1}));
      expect(await repo.tidyBranches('r-1'), (merged: 2, removed: 1));
      expect(adapter.requests.single.path, '/places/restaurants/r-1/tidy');
      expect(
        adapter.requests.single.receiveTimeout,
        const Duration(seconds: 90),
      );
    },
  );
}
