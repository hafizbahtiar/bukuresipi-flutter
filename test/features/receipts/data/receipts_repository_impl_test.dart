import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/receipts/data/receipts_repository_impl.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

void main() {
  late FakeAdapter adapter;
  ReceiptsRepositoryImpl make((int, Object?) Function(RequestOptions) answer) {
    adapter = FakeAdapter(answer);
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: adapter,
    );
    return ReceiptsRepositoryImpl(api.dio);
  }

  const json = {
    'id': 'r-1',
    'status': 'review',
    'shop': 'Port Lepak Sentul',
    'place': {
      'restaurantId': 'x',
      'branchId': 'b-1',
      'name': 'Port Lepak Sentul',
    },
    'visitedAt': '2026-11-08T12:41:00Z',
    'totalSen': 4115,
    'gaps': ['totals_mismatch'],
    'hasImage': true,
  };

  test(
    'a receipt reads its place, UTC time as local, total in sen and gaps',
    () async {
      final r = await make((_) => (200, json)).get('r-1');
      expect(r.place?.branchId, 'b-1');
      expect(r.visitedAt, DateTime.utc(2026, 11, 8, 12, 41).toLocal());
      expect(r.totalSen, 4115);
      expect(r.gaps, ['totals_mismatch']);
      expect(r.inReview, isTrue);
    },
  );

  test('confirm sends the total in sen and the time in UTC', () async {
    final repo = make(
      (_) => (200, {...json, 'status': 'saved', 'hasImage': false}),
    );
    final r = await repo.confirm(
      'r-1',
      totalSen: 4100,
      visitedAt: DateTime.utc(2026, 11, 8, 12, 41).toLocal(),
    );
    expect(r.saved, isTrue);
    final sent = adapter.requests.single;
    expect('${sent.method} ${sent.path}', 'POST /receipts/r-1/confirm');
    expect(sent.data, {
      'totalSen': 4100,
      'visitedAt': '2026-11-08T12:41:00.000Z',
    });
  });

  test('stats read months and places', () async {
    final s = await make(
      (_) => (
        200,
        {
          'currency': 'MYR',
          'totalSen': 5615,
          'visits': 3,
          'months': [
            {'month': '2026-10', 'visits': 1, 'totalSen': 4115},
          ],
          'places': [
            {
              'restaurantId': 'x',
              'name': 'Port Lepak',
              'visits': 2,
              'totalSen': 5115,
              'lastVisitAt': '2026-11-02T04:00:00Z',
            },
          ],
        },
      ),
    ).stats();
    expect(s.totalSen, 5615);
    expect(s.months.single.month, '2026-10');
    expect(s.places.single.visits, 2);
  });

  test('rm and senOf', () {
    expect(rm(4115), 'RM 41.15');
    expect(rm(5), 'RM 0.05');
    expect(senOf('41.15'), 4115);
    expect(senOf('RM 41.1'), 4110);
    expect(senOf('41'), 4100);
    expect(senOf('4,50'), 450);
    expect(senOf('abc'), isNull);
    expect(senOf('41.155'), isNull);
  });
}
