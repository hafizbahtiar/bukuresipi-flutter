import 'package:bukuresipi_flutter/features/places/presentation/pages/places_map_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

void main() {
  test('no pins, no bounds', () {
    expect(pinBounds([place(lat: null)]), isNull);
  });

  test('bounds cover every pinned branch', () {
    final b = pinBounds([
      place(id: 'a', lat: 3.0),
      place(id: 'b', lat: 5.5),
      place(id: 'c', lat: null),
    ])!;
    expect([b.southwest.latitude, b.northeast.latitude], [3.0, 5.5]);
    // LatLng wraps the longitude ((lng + 180) % 360 - 180): float noise.
    expect(b.southwest.longitude, closeTo(101.7, 1e-9));
    expect(b.northeast.longitude, closeTo(101.7, 1e-9));
  });
}
