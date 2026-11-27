import 'package:bukuresipi_flutter/features/places/domain/market.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-23 is a Monday; every clock here is Malaysia time.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 22 + day, hour, minute);

MarketDay d(int day, String opens, String closes) =>
    MarketDay(day: day, opens: opens, closes: closes);

Market m(String id, int distanceM, List<MarketDay> schedule) => Market(
  placeId: 'p$id',
  branchId: id,
  name: id,
  subcategory: 'pasar_malam',
  lat: 3.1,
  lng: 101.7,
  distanceM: distanceM,
  schedule: schedule,
);

void main() {
  test('Malaysia time is UTC+8 whatever the phone is set to', () {
    final now = malaysiaNow(DateTime.utc(2026, 11, 22, 17, 30)); // Sunday UTC
    expect((now.weekday, now.hour, now.minute), (DateTime.monday, 1, 30));
  });

  group('marketToday', () {
    test('a shop with a break: open, then on its break until it opens again, then nothing', () {
      final lunch = [d(1, '11:00', '15:00'), d(1, '17:00', '22:00')];
      expect(
        marketToday(lunch, at(1, 10))?.breakNow,
        false,
      ); // opens later, no break yet
      final open = marketToday(lunch, at(1, 12))!;
      expect((open.openNow, open.slot.closes), (true, '15:00'));
      final rest = marketToday(lunch, at(1, 16))!;
      expect(
        (rest.openNow, rest.breakNow, rest.slot.opens),
        (false, true, '17:00'),
      );
      expect(marketToday(lunch, at(1, 22, 30)), isNull);
    });
    final saturday = [d(6, '17:00', '22:00')];

    test('later today, open, the last minute, and over', () {
      expect(marketToday(saturday, at(6, 16))?.openNow, false);
      expect(marketToday(saturday, at(6, 17))?.openNow, true);
      expect(marketToday(saturday, at(6, 21, 59))?.openNow, true);
      expect(marketToday(saturday, at(6, 22)), isNull);
    });

    test('another day, or days not known, is not today', () {
      expect(marketToday(saturday, at(5, 18)), isNull);
      expect(marketToday(const [], at(6, 18)), isNull);
    });

    test('past midnight: open into the next morning, then over', () {
      final late = [d(6, '18:00', '01:00')];
      expect(marketToday(late, at(6, 23))?.openNow, true);
      expect(marketToday(late, at(7, 0, 30))?.openNow, true);
      expect(marketToday(late, at(7, 1)), isNull);
    });

    test('Sunday night runs into Monday', () {
      expect(marketToday([d(7, '20:00', '02:00')], at(1, 1))?.openNow, true);
    });

    test(
      'open now beats a later slot, and the next slot follows a closed one',
      () {
        final twice = [d(7, '06:00', '12:00'), d(7, '17:00', '22:00')];
        expect(marketToday(twice, at(7, 7))?.slot.opens, '06:00');
        expect(marketToday(twice, at(7, 13))?.slot.opens, '17:00');
        expect(marketToday(twice, at(7, 13))?.openNow, false);
      },
    );

    test('last night still open beats tonight', () {
      final both = [d(6, '18:00', '01:00'), d(7, '18:00', '23:00')];
      final t = marketToday(both, at(7, 0, 30))!;
      expect((t.slot.day, t.openNow), (6, true));
    });
  });

  test('marketsOnToday: open first, then nearest; others left out', () {
    final list = marketsOnToday([
      m('later-near', 100, [d(6, '20:00', '23:00')]),
      m('open-far', 5000, [d(6, '17:00', '22:00')]),
      m('open-near', 900, [d(6, '17:00', '22:00')]),
      m('not-today', 10, [d(1, '17:00', '22:00')]),
      m('unknown', 10, const []),
    ], at(6, 18));
    expect(list.map((e) => e.market.branchId), [
      'open-near',
      'open-far',
      'later-near',
    ]);
  });

  test('reads the API row', () {
    final x = Market.fromJson({
      'placeId': 'p',
      'branchId': 'b',
      'name': 'Pasar Malam SS2',
      'label': null,
      'subcategory': 'pasar_tani',
      'lat': 3,
      'lng': 101.5,
      'distanceM': 120,
      'schedule': [
        {'day': 6, 'opens': '17:00', 'closes': '22:00'},
      ],
      'shape': {
        'type': 'LineString',
        'coordinates': [
          [101.5, 3.0],
          [101.6, 3.1],
        ],
      },
      'savedPlaceId': 's',
    });
    expect((x.lat, x.schedule.single.day, x.savedPlaceId), (3.0, 6, 's'));
    expect(x.shape?['type'], 'LineString');
    expect(x.copyWith(savedPlaceId: 't').savedPlaceId, 't');
  });
}
