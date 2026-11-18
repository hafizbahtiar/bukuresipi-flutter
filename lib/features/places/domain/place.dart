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
    this.pages = const [],
    this.photos = const [],
    this.placeId,
    this.jakim,
  });

  final BranchDraft draft;
  final List<String> sources;
  final bool aiUsed;
  final bool changed;
  final String? summary;
  final List<String> warnings;

  /// Every pin found (current, the draft's, HERE, GrabMaps), to compare before saving.
  final List<PinCandidate> candidates;

  /// The web pages read about the shop, to open and check.
  final List<({String url, String? title})> pages;

  /// Up to 3 photos from those pages: one may become the restaurant's cover.
  final List<String> photos;

  /// The branch's restaurant (that cover's target).
  final String? placeId;

  /// JAKIM's halal directory rows for the brand in the branch's state; [pick] = the row the AI named and Clef
  /// confirmed as this outlet (null = none); [url] = the directory page. null = JAKIM did not answer.
  final ({String url, List<JakimRow> rows, int? pick})? jakim;
}

/// Owner, Edit branch > Halal: the company behind the branch's JAKIM certificate. [status] only after a refresh:
/// ok | unavailable (JAKIM down, the stored info kept) | none (no certificate or company).
/// Owner, Edit place > Halal: each certified branch with its company. [status]/[left] only after a refresh.
typedef PlaceCompanies = ({
  String? status,
  int left,
  List<({String branchId, String? label, BranchCompany info})> branches,
});

class BranchCompany {
  const BranchCompany({
    this.premise,
    this.brand,
    this.premiseAddress,
    this.company,
    this.status,
    this.source,
  });

  factory BranchCompany.fromJson(Map<String, dynamic> j) {
    final c = j['company'] as Map<String, dynamic>?;
    return BranchCompany(
      premise: j['premise'] as String?,
      brand: j['brand'] as String?,
      premiseAddress: j['premiseAddress'] as String?,
      status: j['status'] as String?,
      source: j['source'] as String?,
      company: c == null
          ? null
          : HalalCompany(
              code: c['code'] as String,
              name: c['name'] as String,
              address: c['address'] as String?,
              state: c['state'] as String?,
              phone: c['phone'] as String?,
              fax: c['fax'] as String?,
              email: c['email'] as String?,
              website: c['website'] as String?,
              reference: c['reference'] as String?,
              readAt: c['readAt'] == null
                  ? null
                  : DateTime.parse(c['readAt'] as String),
            ),
    );
  }

  /// [source] owner = paired by hand; null = matched by the JAKIM check.
  final String? premise, brand, premiseAddress, status, source;
  final HalalCompany? company;
}

/// A company holding JAKIM certificates (its halal.gov.my page). [readAt] null = only its name, page not read yet.
class HalalCompany {
  const HalalCompany({
    required this.code,
    required this.name,
    this.address,
    this.state,
    this.phone,
    this.fax,
    this.email,
    this.website,
    this.reference,
    this.readAt,
  });

  final String code, name;
  final String? address, state, phone, fax, email, website, reference;
  final DateTime? readAt;
}

/// The owner's "Check JAKIM" on one branch: [status] found (saved) | none | unavailable; [rows] to choose from.
typedef JakimCheck = ({
  String status,
  String? url,
  List<JakimRow> rows,
  int? pick,
});

/// Edit place > Halal: one of the brand's JAKIM outlets, with the branch holding its certificate ([branchId]) and
/// a branch at the same postcode ([nearBranchId]).
typedef JakimOutlet = ({JakimRow row, String? branchId, String? nearBranchId});

/// The brand's JAKIM outlets: [status] ok | unavailable; [url] = the directory page; [more] = past 100 rows (in part).
typedef JakimOutlets = ({
  String status,
  String? url,
  List<JakimOutlet> rows,
  bool more,
});

/// One outlet in JAKIM's halal directory (a draft's `jakim` row).
typedef JakimRow = ({
  String premise,
  String? company,
  String address,
  DateTime expiresOn,
});

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

/// [source] 'jakim' = a JAKIM halal-listed outlet: [name] as JAKIM lists it, no pin (another source pins it).
typedef PinHit = ({
  double? lat,
  double? lng,
  String address,
  String? city,
  String? state,
  String source,
  String? name,
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
    this.visited = false,
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

  /// The caller has a confirmed receipt here (Book: "Been there"; none = "Want to try"). Their own receipts only.
  final bool visited;
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
    visited: visited,
  );
}

/// [halalClaim]: 'says_halal' | 'says_not_halal' | null. It is what a post SAYS (quoted, with its link), never a
/// certification: show the quote and the source, never a "halal" badge.
class PlaceRestaurant {
  const PlaceRestaurant({
    required this.id,
    required this.name,
    this.category = 'food',
    this.subcategory,
    this.cuisine,
    this.halalClaim,
    this.halalQuote,
    this.halalSourceUrl,
    this.cover,
    this.halalBrand,
  });

  final String id;
  final String name;

  /// JAKIM lists [outlets] premises under this name across Malaysia ([url] = that list). Each premises is certified
  /// on its own: a branch without its own `halalCert` is NOT confirmed. null = none or not checked.
  final ({int outlets, String url})? halalBrand;

  /// One of [categories] (broad); places saved before categories existed are 'food'.
  final String category;

  /// One of [categories]\[category] (specific), or null = not set.
  final String? subcategory;
  final String? cuisine;
  final String? halalClaim;
  final String? halalQuote;
  final String? halalSourceUrl;

  /// The owner's chosen photo (PlacesRepository.restaurantCover); changes when another is picked. null = none.
  final String? cover;

  /// The server's lists (PLACE_SUBCATEGORIES): each category and its subcategories.
  static const categories = <String, List<String>>{
    'food': [
      'restaurant', 'cafe', 'stall', 'mamak', 'kopitiam', //
      'food_court', 'bakery', 'dessert', 'fast_food',
    ],
    'shop': ['grocery', 'market', 'mall'],
    'attraction': ['museum', 'theme_park', 'landmark'],
    'stay': ['hotel', 'homestay', 'resort'],
    'outdoor': ['park', 'beach', 'waterfall', 'hiking'],
    'other': [],
  };

  /// Cuisine and halal only mean something for food.
  bool get isFood => category == 'food';
}

/// A branch's row in JAKIM's halal directory (halal.gov.my), found by the server's monthly check.
/// [premise] = JAKIM's outlet name as printed; [url] = the directory's own page for it.
class HalalCert {
  const HalalCert({
    required this.premise,
    required this.expiresOn,
    required this.url,
    required this.checkedAt,
  });

  final String premise;
  final DateTime expiresOn;
  final String url;
  final DateTime checkedAt;

  /// Past its expiry day (the certificate is valid through that day).
  bool expiredAt(DateTime now) =>
      now.isAfter(expiresOn.add(const Duration(days: 1)));

  static HalalCert? fromJson(Object? j) => j is Map<String, dynamic>
      ? HalalCert(
          premise: j['premise'] as String,
          expiresOn: DateTime.parse(j['expiresOn'] as String),
          url: j['url'] as String,
          checkedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['checkedAt'] as num).toInt(),
          ),
        )
      : null;
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
    this.closed = false,
    this.rating = const RatingSummary(),
    this.halalCert,
    this.cover,
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

  /// Permanently closed: still in the book, no longer suggested nearby or in search.
  final bool closed;

  /// Community stars for this canonical branch; `canRate` is decided by the server.
  final RatingSummary rating;

  /// JAKIM's halal certificate for this outlet; null = not found, never "not halal".
  final HalalCert? halalCert;

  /// This outlet's own cover id (the owner's photo of it); null = none: the place's shows.
  final String? cover;

  Branch copyWith({RatingSummary? rating}) => Branch(
    id: id,
    label: label,
    address: address,
    city: city,
    state: state,
    lat: lat,
    lng: lng,
    pinSource: pinSource,
    closed: closed,
    rating: rating ?? this.rating,
    halalCert: halalCert,
  );

  /// Set by hand in the app: shown, but not verified yet.
  bool get pinnedByUser => pinSource == 'user';

  /// Set by the owner: shared by everyone and not overwritten by a hand pin.
  bool get pinnedByOwner => pinSource == 'owner';

  /// Google Maps search by coordinates (opens the Maps app when installed). null = no pin.
  String? get mapsUrl => hasPin ? mapsSearchUrl(lat!, lng!) : null;

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

/// Google Maps search by coordinates (opens the Maps app when installed).
String mapsSearchUrl(double lat, double lng) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$lat,$lng'},
).toString();
