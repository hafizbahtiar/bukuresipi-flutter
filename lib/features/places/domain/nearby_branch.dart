import 'rating.dart';

/// A pinned branch near the map camera, from GET /places/nearby.
class NearbyBranch {
  const NearbyBranch({
    required this.branchId,
    required this.restaurantId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.saved,
    this.label,
    this.address,
    this.cuisine,
    this.halalClaim,
    this.halalQuote,
    this.halalSourceUrl,
    this.placeId,
    this.rating = const RatingSummary(),
  });

  final String branchId;
  final String restaurantId;
  final String name;
  final String? label;
  final String? address;
  final double lat;
  final double lng;

  /// Straight-line distance from the camera centre, in metres.
  final int distanceM;

  final String? cuisine;
  final String? halalClaim;
  final String? halalQuote;
  final String? halalSourceUrl;

  /// The caller already has this restaurant on their map.
  final bool saved;

  /// The caller's user_place public id when [saved].
  final String? placeId;

  /// Community stars for this canonical branch; `canRate` is decided by the server.
  final RatingSummary rating;

  NearbyBranch copyWith({
    bool? saved,
    String? placeId,
    int? distanceM,
    RatingSummary? rating,
  }) => NearbyBranch(
    branchId: branchId,
    restaurantId: restaurantId,
    name: name,
    label: label,
    address: address,
    lat: lat,
    lng: lng,
    distanceM: distanceM ?? this.distanceM,
    cuisine: cuisine,
    halalClaim: halalClaim,
    halalQuote: halalQuote,
    halalSourceUrl: halalSourceUrl,
    saved: saved ?? this.saved,
    placeId: placeId ?? this.placeId,
    rating: rating ?? this.rating,
  );
}

/// "350 m" under a kilometre, "2.4 km" above.
String distanceText(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// A map search result (GET /places/search): a branch in the app ([branchId]), or a place not in the app yet
/// ([poiId]: Overture or OpenStreetMap), saved with PlacesController.savePoi.
class PlaceHit {
  const PlaceHit({
    this.branchId,
    this.poiId,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.saved = false,
  });

  final String? branchId;
  final String? poiId;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final int distanceM;
  final bool saved;
}
