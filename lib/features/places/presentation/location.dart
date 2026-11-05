import 'package:geolocator/geolocator.dart';

/// Foreground position updates (50 m filter). Callers stop listening when the map is not visible;
/// there is no background tracking.
Stream<({double lat, double lng})> positionUpdates() =>
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).map((p) => (lat: p.latitude, lng: p.longitude));

/// One location ask: permission if needed, then one high-accuracy fix. Null = refused or unavailable, or no fix
/// within [timeLimit] (the permission dialog does not count against it).
Future<Position?> currentPosition({Duration? timeLimit}) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Where to open a map when nothing better is known: the phone's last fix (instant, no GPS wait), else one fresh
/// fix of at most 5 s. Null = refused or unavailable.
Future<({double lat, double lng})?> startPosition() async {
  try {
    if (await Geolocator.getLastKnownPosition() case final p?) {
      return (lat: p.latitude, lng: p.longitude);
    }
  } catch (_) {} // no permission yet: currentPosition asks
  final p = await currentPosition(timeLimit: const Duration(seconds: 5));
  return p == null ? null : (lat: p.latitude, lng: p.longitude);
}
