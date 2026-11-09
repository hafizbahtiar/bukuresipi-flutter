import 'rating.dart';

/// Whether a branch edit is private to the caller or changes the shared branch (owner only).
enum BranchEditScope { personal, shared }

/// An owner-only AI/map suggestion. It is a draft: the owner reviews it before saving.
class BranchDraft {
  const BranchDraft({
    this.label,
    this.address,
    this.city,
    this.state,
    this.lat,
    this.lng,
  });

  final String? label;
  final String? address;
  final String? city;
  final String? state;
  final double? lat;
  final double? lng;
}

class BranchSuggestion {
  const BranchSuggestion({
    required this.draft,
    required this.sources,
    required this.aiUsed,
    required this.changed,
    this.summary,
    this.warnings = const [],
    this.candidates = const [],
  });

  final BranchDraft draft;
  final List<String> sources;
  final bool aiUsed;
  final bool changed;
  final String? summary;
  final List<String> warnings;

  /// Every pin found (current, the draft's, HERE, GrabMaps), to compare before saving.
  final List<PinCandidate> candidates;
}

/// One pin a source gave for a branch. [source]: 'current', 'draft:<source>', 'here', 'grab'.
/// [fromDraftM] = metres from the draft's pin; null when the draft has none.
typedef PinCandidate = ({
  String source,
  double lat,
  double lng,
  String? address,
  int? fromDraftM,
});

/// "Find location": [triedToday] = the server already looked within a day, so it searched nothing.
enum LocateResult { found, triedToday, notFound }

/// A pin read from a pasted Google Maps link; [name] when the link names the place.
typedef MapsPin = ({double lat, double lng, String? name});

/// One hit of the owner's search on a chosen map source (osm, here, grab); [source] is the service that answered.
/// A state and its official towns (the server's postcode list), for the branch form's dropdowns.
typedef AreaState = ({String name, List<String> towns});

typedef PinHit = ({
  double lat,
  double lng,
  String address,
  String? city,
  String? state,
  String source,
});

/// A restaurant on the user's map. [restaurant] and its [branches] are shared by all users; [note] is the user's own.
/// In a family the book also holds the members' saves: [mine] false = only a family member saved it.
class Place {
  const Place({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.branchId,
    required this.restaurant,
    required this.branches,
    this.sourceUrl,
    this.shareId,
    this.mine = true,
    this.private = false,
    this.savedBy = const [],
  });

  final String id;

  /// The caller saved it (note, Only me, remove and rating are theirs). false = "Save to my book".
  final bool mine;

  /// "Only me": the caller's save is kept out of the family book.
  final bool private;

  /// Who saved it, the caller first (name null + isMe: "You"). A family member also has [userId] + [avatar]
  /// (their photo, for the map pin).
  final List<({String? name, bool isMe, String? userId, String? avatar})>
  savedBy;

  /// The family members who saved it (not the caller).
  List<String> get savedByOthers => [
    for (final s in savedBy)
      if (!s.isMe) s.name ?? '?',
  ];
  final String? note;
  final DateTime createdAt;

  /// The branch the shared post was about, when known.
  final String? branchId;

  /// The link the user shared; null for a screenshot.
  final String? sourceUrl;

  /// The share behind this place: its screenshot or post thumbnail (ShareRepository.image).
  final String? shareId;
  final PlaceRestaurant restaurant;
  final List<Branch> branches;

  Branch? get savedBranch =>
      branches.where((b) => b.id == branchId).firstOrNull ??
      branches.firstOrNull;

  /// Branches with coordinates. A branch that did not geocode has none: no pin beats a wrong pin.
  List<Branch> get pins => branches.where((b) => b.hasPin).toList();

  static const _keep = Object();

  // `note: null` must clear the note, so "not passed" is a sentinel, not null.
  Place copyWith({
    Object? note = _keep,
    List<Branch>? branches,
    bool? private,
  }) => Place(
    id: id,
    mine: mine,
    private: private ?? this.private,
    savedBy: savedBy,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    branchId: branchId,
    restaurant: restaurant,
    branches: branches ?? this.branches,
    sourceUrl: sourceUrl,
    shareId: shareId,
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
    this.cover,
  });

  final String id;
  final String name;
  final String? cuisine;
  final String? halalClaim;
  final String? halalQuote;
  final String? halalSourceUrl;

  /// The owner's chosen photo (PlacesRepository.restaurantCover); changes when another is picked. null = none.
  final String? cover;
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
    this.pinSource,
    this.rating = const RatingSummary(),
  });

  final String id;
  final String? label;
  final String? address;
  final String? city;
  final String? state;
  final double? lat;
  final double? lng;

  /// 'osm' | 'nominatim' | 'photon' | 'overture' | 'here' | 'maps_link' | 'web' | 'user' | 'owner' | null.
  final String? pinSource;

  /// Community stars for this canonical branch; `canRate` is decided by the server.
  final RatingSummary rating;

  Branch copyWith({RatingSummary? rating}) => Branch(
    id: id,
    label: label,
    address: address,
    city: city,
    state: state,
    lat: lat,
    lng: lng,
    pinSource: pinSource,
    rating: rating ?? this.rating,
  );

  /// Set by hand in the app: shown, but not verified yet.
  bool get pinnedByUser => pinSource == 'user';

  /// Set by the owner: shared by everyone and not overwritten by a hand pin.
  bool get pinnedByOwner => pinSource == 'owner';

  /// Google Maps search by coordinates (opens the Maps app when installed). null = no pin.
  String? get mapsUrl => hasPin
      ? Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '$lat,$lng',
        }).toString()
      : null;

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
