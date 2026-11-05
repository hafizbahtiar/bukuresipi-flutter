import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance text is metres under 1 km, one decimal km above', () {
    expect(distanceText(0), '0 m');
    expect(distanceText(350), '350 m');
    expect(distanceText(999), '999 m');
    expect(distanceText(1000), '1.0 km');
    expect(distanceText(2400), '2.4 km');
  });
}
