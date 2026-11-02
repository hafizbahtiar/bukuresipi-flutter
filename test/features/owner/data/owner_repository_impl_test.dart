import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/owner/data/owner_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

void main() {
  late FakeAdapter adapter;
  OwnerRepositoryImpl make((int, Object?) Function(RequestOptions) answer) {
    adapter = FakeAdapter(answer);
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: adapter,
    );
    return OwnerRepositoryImpl(api.dio);
  }

  test('stats are read with every meter', () async {
    final repo = make(
      (_) => (
        200,
        {
          'users': {'total': 12, 'newThisWeek': 3},
          'shares': {'today': 7, 'failedToday': 2},
          'meters': [
            {
              'code': 'geo:nominatim',
              'name': 'Nominatim',
              'vendorUrl': null,
              'freeUnits': null,
              'cap': 100,
              'active': true,
              'used': 90,
            },
          ],
        },
      ),
    );
    final s = await repo.getStats();
    expect(
      [s.usersTotal, s.usersNewThisWeek, s.sharesToday, s.failedToday],
      [12, 3, 7, 2],
    );
    expect(s.meters.single.share, 0.9);
  });

  test(
    'a meter change PATCHes only what changed; the code is escaped in the path',
    () async {
      final repo = make(
        (_) => (
          200,
          {
            'code': 'geo:nominatim',
            'name': 'N',
            'cap': 50,
            'active': false,
            'used': 1,
          },
        ),
      );
      final m = await repo.updateMeter('geo:nominatim', cap: 50);
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/owner/meters/geo%3Anominatim');
      expect(adapter.requests.single.data, {'cap': 50});
      expect([m.cap, m.active], [50, false]);
    },
  );

  test('users are searched with q; failed shares carry their gaps', () async {
    final repo = make(
      (o) => o.path == '/owner/users'
          ? (
              200,
              {
                'users': [
                  {
                    'id': 'u1',
                    'email': 'siti@b.c',
                    'role': 'user',
                    'verified': false,
                    'createdAt': '2026-11-01 08:00:00',
                    'shares': 2,
                  },
                ],
              },
            )
          : (
              200,
              {
                'shares': [
                  {
                    'id': 's1',
                    'createdAt': '2026-11-02 12:00:00',
                    'status': 'done',
                    'kind': 'other',
                    'input': 'url',
                    'platform': 'tiktok',
                    'sourceUrl': 'https://vt.tiktok.com/x',
                    'error': null,
                    'gaps': ['unreadable'],
                    'caption': null,
                  },
                ],
              },
            ),
    );
    final users = await repo.listUsers(query: 'siti');
    expect(adapter.requests.single.queryParameters, {'q': 'siti'});
    expect(
      [users.single.email, users.single.verified, users.single.shares],
      ['siti@b.c', false, 2],
    );
    final shares = await repo.failedShares();
    expect(shares.single.gaps, ['unreadable']);
    expect(shares.single.createdAt.isUtc, isTrue);
  });
}
