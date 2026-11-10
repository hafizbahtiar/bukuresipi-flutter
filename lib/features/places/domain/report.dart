import 'nearby_branch.dart';
import 'place.dart';

enum ReportTarget { branch, restaurant }

enum ReportField {
  location,
  label,
  address,
  city,
  state,
  name,
  cuisine,
  status,
}

class ReportBranch {
  const ReportBranch({
    required this.id,
    this.label,
    this.address,
    this.city,
    this.state,
    this.lat,
    this.lng,
    this.closed = false,
  });

  final String id;
  final String? label;
  final String? address;
  final String? city;
  final String? state;
  final double? lat;
  final double? lng;

  /// Permanently closed (a `status` report the owner applied).
  final bool closed;

  String get title => label ?? address ?? 'Branch';
}

/// Everything the report sheet needs: the restaurant, its branches, and the caller's saved place id (when known).
class ReportSubject {
  const ReportSubject({
    required this.restaurantId,
    required this.restaurantName,
    required this.branches,
    this.placeId,
    this.cuisine,
  });

  final String restaurantId;
  final String restaurantName;
  final String? cuisine;
  final String? placeId;
  final List<ReportBranch> branches;

  factory ReportSubject.fromPlace(Place place) => ReportSubject(
    restaurantId: place.restaurant.id,
    restaurantName: place.restaurant.name,
    cuisine: place.restaurant.cuisine,
    placeId: place.id,
    branches: [
      for (final b in place.branches)
        ReportBranch(
          id: b.id,
          label: b.label,
          address: b.address,
          city: b.city,
          state: b.state,
          lat: b.lat,
          lng: b.lng,
          closed: b.closed,
        ),
    ],
  );

  factory ReportSubject.fromNearby(NearbyBranch branch) => ReportSubject(
    restaurantId: branch.restaurantId,
    restaurantName: branch.name,
    cuisine: branch.cuisine,
    placeId: branch.placeId,
    branches: [
      ReportBranch(
        id: branch.branchId,
        label: branch.label,
        address: branch.address,
        lat: branch.lat,
        lng: branch.lng,
      ),
    ],
  );
}

class ReportDraft {
  const ReportDraft({
    required this.target,
    required this.targetId,
    required this.field,
    this.lat,
    this.lng,
    this.value,
    this.note,
  });

  final ReportTarget target;
  final String targetId;
  final ReportField field;
  final double? lat;
  final double? lng;
  final String? value;
  final String? note;
}
