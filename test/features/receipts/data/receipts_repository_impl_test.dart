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

  const splitJson = {
    'people': [
      {'name': 'Me', 'paid': false},
      {'name': 'Ali', 'paid': true},
    ],
    'portions': [
      {'position': 0, 'person': 1, 'quantity': 1},
    ],
    'shares': [
      {
        'person': 0,
        'amountSen': 1840,
        'lines': ['Nasi Lemak', 'Teh Ais'],
      },
      {
        'person': 1,
        'amountSen': 2275,
        'lines': ['Nasi Lemak'],
      },
    ],
    'totalSen': 4115,
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
      expect(r.charges, isEmpty); // a list row has none
      expect(r.hasSplit, isFalse); // an older server sends nothing
    },
  );

  test(
    'charges in bill order: missing ones skipped, other lines before rounding',
    () async {
      final r = await make(
        (_) => (
          200,
          {
            ...json,
            'charges': {
              'subtotalSen': 2980,
              'discountSen': -500,
              'serviceSen': null,
              'taxSen': 158,
              'roundingSen': 2,
              'other': [
                {'name': 'Takeaway Charge', 'amountSen': 100},
              ],
            },
          },
        ),
      ).get('r-1');
      expect(r.charges, [
        (kind: 'subtotal', name: null, amountSen: 2980),
        (kind: 'discount', name: null, amountSen: -500),
        (kind: 'tax', name: null, amountSen: 158),
        (kind: 'other', name: 'Takeaway Charge', amountSen: 100),
        (kind: 'rounding', name: null, amountSen: 2),
      ]);
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

  test('hasSplit and a day of calories with its eaten lines', () async {
    final r = await make((_) => (200, {...json, 'hasSplit': true})).get('r-1');
    expect(r.hasSplit, isTrue);
    final today = await make(
      (_) => (
        200,
        {
          'eatenKcal': 1250,
          'target': 2000,
          'hasEstimate': true,
          'unknownEaten': 0,
          'receipts': [
            {
              'id': 'r-1',
              'shop': 'Port Lepak',
              'visitedAt': '2026-11-10T12:41:00Z',
              'eatenKcal': 1250,
              'items': [
                {
                  'name': 'Nasi Lemak',
                  'eaten': 2,
                  'kcal': 640,
                  'kcalSource': 'ai',
                },
                {'name': 'Teh', 'eaten': 0.5, 'kcal': null, 'kcalSource': null},
              ],
            },
          ],
        },
      ),
    ).calories();
    expect(today.receipts.single.shop, 'Port Lepak');
    expect(
      today.receipts.single.visitedAt,
      DateTime.utc(2026, 11, 10, 12, 41).toLocal(),
    );
    expect(today.receipts.single.eatenKcal, 1250);
    expect(today.receipts.single.items.last, (
      name: 'Teh',
      eaten: 0.5,
      kcal: null,
      kcalSource: null,
    ));
  });

  test('calorieDays asks for the range and parses the days', () async {
    final days = await make(
      (_) => (
        200,
        {
          'days': [
            {
              'date': '2026-11-09',
              'eatenKcal': 300,
              'hasEstimate': false,
              'unknownEaten': 0,
            },
            {
              'date': '2026-11-10',
              'eatenKcal': 800,
              'hasEstimate': true,
              'unknownEaten': 1,
            },
          ],
          'target': 2000,
        },
      ),
    ).calorieDays(days: 7);
    final sent = adapter.requests.single;
    expect('${sent.method} ${sent.path}', 'GET /receipts/calories/days');
    expect(sent.queryParameters, {'days': 7});
    expect(days.days.map((d) => d.eatenKcal), [300, 800]);
    expect(days.days.first.date, DateTime(2026, 11, 9)); // local midnight
    expect(days.target, 2000);
  });

  test(
    'split: reads the shares, saves the whole state and clears it',
    () async {
      final repo = make(
        (o) => switch (o.method) {
          'GET' => (200, splitJson),
          'PUT' => (
            200,
            {
              ...splitJson,
              'people': [
                {'name': 'Me', 'paid': false},
                {'name': 'Ali', 'paid': true},
              ],
              'portions': [
                {'position': 0, 'person': 1, 'quantity': 1},
              ],
            },
          ),
          _ => (204, null),
        },
      );
      final split = await repo.split('r-1');
      expect(split.people.map((p) => p.name), ['Me', 'Ali']);
      expect(split.shares.first.amountSen, 1840);
      expect(split.shares.last.lines, ['Nasi Lemak']);
      expect(split.totalSen, 4115);
      final saved = await repo.saveSplit(
        'r-1',
        people: [(name: 'Me', paid: false), (name: 'Ali', paid: true)],
        portions: [(position: 0, person: 1, quantity: 1)],
      );
      expect(saved.people.last.paid, isTrue);
      final sent = adapter.requests.last;
      expect('${sent.method} ${sent.path}', 'PUT /receipts/r-1/split');
      expect(sent.data, {
        'people': [
          {'name': 'Me', 'paid': false},
          {'name': 'Ali', 'paid': true},
        ],
        'portions': [
          {'position': 0, 'person': 1, 'quantity': 1.0},
        ],
      });
      await repo.clearSplit('r-1');
      final deleted = adapter.requests.last;
      expect('${deleted.method} ${deleted.path}', 'DELETE /receipts/r-1/split');
    },
  );
}
