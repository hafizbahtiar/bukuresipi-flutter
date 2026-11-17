import 'package:bukuresipi_flutter/core/ads/ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an ad after the 6th card, then after every 12 more; none in a short feed',
    () {
      expect(adSlots(5), isEmpty);
      expect(adSlots(6), [6]);
      expect(adSlots(17), [6]);
      expect(adSlots(18), [6, 18]);
      expect(adSlots(40), [6, 18, 30]);
    },
  );

  test('withAds puts each slot after its card; a failed slot is left out', () {
    final cards = [for (var i = 1; i <= 20; i++) 'c$i'];
    final shown = withAds(cards, (s) => 'ad$s');
    expect(shown.indexOf('ad0'), 6); // after c6
    expect(shown[shown.indexOf('ad1') - 1], 'c18');
    expect(shown.length, 22);
    final skipped = withAds(cards, (s) => 'ad$s', skip: {0});
    expect(skipped, isNot(contains('ad0')));
    expect(skipped.length, 21);
    expect(withAds(['a', 'b'], (s) => 'ad$s'), ['a', 'b']);
  });
}
