import 'rating.dart';

/// A pinned branch near the map camera, from GET /places/nearby.
class NearbyBranch {
  const NearbyBranch({
    required this.branchId,
    required this.placeId,
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
    this.savedPlaceId,
    this.rating = const RatingSummary(),
    this.cover,
  });

  final String branchId;
  final String placeId;
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

  /// The caller's user_place public id when [saved] (the place page's id), not the shared [placeId].
  final String? savedPlaceId;

  /// Community stars for this canonical branch; `canRate` is decided by the server.
  final RatingSummary rating;

  /// The restaurant's cover photo id (PlacesRepository.restaurantCover); null = none.
  final String? cover;

  NearbyBranch copyWith({
    bool? saved,
    String? savedPlaceId,
    int? distanceM,
    RatingSummary? rating,
  }) => NearbyBranch(
    branchId: branchId,
    placeId: placeId,
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
    savedPlaceId: savedPlaceId ?? this.savedPlaceId,
    rating: rating ?? this.rating,
    cover: cover,
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
