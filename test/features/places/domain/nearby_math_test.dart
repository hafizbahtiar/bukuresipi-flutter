import 'package:bukuresipi_flutter/features/places/domain/nearby_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

void main() {
  test('distance is measured from the device, not the search camera', () {
    final rows = sortByDistanceFrom(
      [
        nearbyBranch(branchId: 'far', lat: 3.16),
        nearbyBranch(branchId: 'near', lat: 3.15),
      ],
      3.15,
      101.71,
    );
    expect(rows.map((r) => r.branchId), ['near', 'far']);
    expect(rows.first.distanceM, 0);
    expect(rows.last.distanceM, closeTo(1112, 15));
  });

  test('the Malaysia box matches the API', () {
    expect(inMalaysia(3.15, 101.71), isTrue);
    expect(inMalaysia(7.4, 119.3), isTrue);
    expect(inMalaysia(51.5, -0.12), isFalse);
    expect(inMalaysia(3.15, 90), isFalse);
  });

  test('distanceKm is the great-circle distance', () {
    expect(distanceKm(3.15, 101.71, 3.15, 101.71), 0);
    expect(distanceKm(3.15, 101.71, 3.16, 101.71), closeTo(1.11, 0.02));
    expect(distanceKm(3.15, 101.71, 4.15, 101.71), closeTo(111.2, 0.5));
  });
}
