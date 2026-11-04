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

/// One location ask: permission if needed, then one high-accuracy fix. Null = refused or unavailable.
Future<Position?> currentPosition() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
}
