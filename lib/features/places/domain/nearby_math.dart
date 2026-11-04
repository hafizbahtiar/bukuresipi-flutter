import 'dart:math' as math;

import 'nearby_branch.dart';

const _earthKm = 6371.0;

double _radians(double degrees) => degrees * math.pi / 180;

/// The API's Malaysia box: no nearby call outside it.
bool inMalaysia(double lat, double lng) =>
    lat >= 0.8 && lat <= 7.4 && lng >= 99.6 && lng <= 119.3;

/// Great-circle distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthKm * math.asin(math.sqrt(h));
}

/// Re-measures every branch from the device's fix and sorts by that distance. The server's distance is
/// relative to the same point, but the app keeps the calculation on-device.
List<NearbyBranch> sortByDistanceFrom(
  Iterable<NearbyBranch> places,
  double lat,
  double lng,
) => [
  for (final p in places)
    p.copyWith(distanceM: (distanceKm(lat, lng, p.lat, p.lng) * 1000).round()),
]..sort((a, b) => a.distanceM.compareTo(b.distanceM));
