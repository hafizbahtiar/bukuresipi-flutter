/// A restaurant on the user's map. [restaurant] and its [branches] are shared by all users; [note] is the user's own.
class Place {
  const Place({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.branchId,
    required this.restaurant,
    required this.branches,
  });

  final String id;
  final String? note;
  final DateTime createdAt;

  /// The branch the shared post was about, when known.
  final String? branchId;
  final PlaceRestaurant restaurant;
  final List<Branch> branches;

  Branch? get savedBranch =>
      branches.where((b) => b.id == branchId).firstOrNull ??
      branches.firstOrNull;

  /// Branches with coordinates. A branch that did not geocode has none: no pin beats a wrong pin.
  List<Branch> get pins => branches.where((b) => b.hasPin).toList();

  Place copyWith({String? note}) => Place(
    id: id,
    note: note,
    createdAt: createdAt,
    branchId: branchId,
    restaurant: restaurant,
    branches: branches,
  );
}

/// [halalClaim]: 'says_halal' | 'says_not_halal' | null. It is what a post SAYS (quoted, with its link), never a
/// certification: show the quote and the source, never a "halal" badge.
class PlaceRestaurant {
  const PlaceRestaurant({
    required this.id,
    required this.name,
    this.cuisine,
    this.halalClaim,
    this.halalQuote,
    this.halalSourceUrl,
  });

  final String id;
  final String name;
  final String? cuisine;
  final String? halalClaim;
  final String? halalQuote;
  final String? halalSourceUrl;
}

class Branch {
  const Branch({
    required this.id,
    this.label,
    this.address,
    this.city,
    this.state,
    this.lat,
    this.lng,
  });

  final String id;
  final String? label;
  final String? address;
  final String? city;
  final String? state;
  final double? lat;
  final double? lng;

  bool get hasPin => lat != null && lng != null;

  /// "Jalan Ampang, Kuala Lumpur": whatever is known, for one line under a name.
  String? get where {
    final parts = [
      address,
      city,
      state,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
