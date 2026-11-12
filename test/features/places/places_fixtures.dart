import 'dart:typed_data';

import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/places_repository.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/domain/report.dart';
import 'package:bukuresipi_flutter/features/places/domain/review.dart';

const placeJson = {
  'id': 'p-1',
  'note': 'Dishes: Ayam goreng',
  'createdAt': '2026-11-02 12:00:00',
  'branchId': 'b-2',
  'sourceUrl': 'https://www.tiktok.com/@makan/video/1',
  'restaurant': {
    'id': 'r-1',
    'name': 'Nasi Kandar Pelita',
    'cuisine': null,
    'halalClaim': 'says_halal',
    'halalQuote': 'Halal ya',
    'halalSourceUrl': 'https://www.tiktok.com/@makan/video/1',
  },
  'branches': [
    {
      'id': 'b-1',
      'label': 'Pelita Mars',
      'address': null,
      'city': null,
      'state': null,
      'lat': null,
      'lng': null,
    },
    {
      'id': 'b-2',
      'label': 'Pelita Jalan Ampang',
      'address': 'Jalan Ampang',
      'city': 'Kuala Lumpur',
      'state': null,
      'lat': 3.1579,
      'lng': 101.7123,
      'pinSource': 'user',
    },
  ],
};

Place place({
  String id = 'p-1',
  String name = 'Nasi Kandar Pelita',
  double? lat = 3.1579,
  String? halal = 'says_halal',
  String? sourceUrl,
  RatingSummary? rating,
}) => Place(
  id: id,
  sourceUrl: sourceUrl,
  note: null,
  createdAt: DateTime.utc(2026, 11, 2),
  branchId: 'b-1',
  restaurant: PlaceRestaurant(
    id: 'r-$id',
    name: name,
    halalClaim: halal,
    halalQuote: halal == null ? null : 'Halal ya',
    halalSourceUrl: halal == null
        ? null
        : 'https://www.tiktok.com/@makan/video/1',
  ),
  branches: [
    Branch(
      id: 'b-1',
      label: '$name Ampang',
      lat: lat,
      lng: lat == null ? null : 101.7,
      pinSource: lat == null ? null : 'osm',
      rating: rating ?? const RatingSummary(),
    ),
  ],
);

const nearbyBranchJson = {
  'branchId': 'b-1',
  'restaurantId': 'r-1',
  'name': 'Kedai Sederhana',
  'label': 'Kedai Sederhana Bangsar',
  'address': 'Jalan Telawi',
  'lat': 3.16,
  'lng': 101.71,
  'distanceM': 2400,
  'cuisine': 'Melayu',
  'halalClaim': 'says_halal',
  'halalQuote': 'Halal ya',
  'halalSourceUrl': 'https://www.tiktok.com/@makan/video/1',
  'saved': false,
  'placeId': null,
};

NearbyBranch nearbyBranch({
  String branchId = 'b-1',
  String name = 'Kedai Sederhana',
  double lat = 3.16,
  double lng = 101.71,
  int distanceM = 2400,
  bool saved = false,
  String? placeId,
  RatingSummary? rating,
}) => NearbyBranch(
  branchId: branchId,
  restaurantId: 'r-1',
  name: name,
  label: 'Kedai Sederhana Bangsar',
  address: 'Jalan Telawi',
  lat: lat,
  lng: lng,
  distanceM: distanceM,
  cuisine: 'Melayu',
  halalClaim: 'says_halal',
  halalQuote: 'Halal ya',
  halalSourceUrl: 'https://www.tiktok.com/@makan/video/1',
  saved: saved,
  placeId: placeId,
  rating: rating ?? const RatingSummary(),
);

class FakePlaces implements PlacesRepository {
  List<Place> places = [];
  Object? error;
  final removed = <String>[];
  final notes = <String, String?>{};
  List<NearbyBranch> nearbyResults = [];
  Object? nearbyError;
  final nearbyCalls = <(double, double, double)>[];
  final savedBranches = <String>[];
  Object? saveBranchError;
  Place? saveBranchResult;
  final reports = <ReportDraft>[];
  Object? reportError;

  @override
  Future<List<Place>> list() async {
    if (error != null) throw error!;
    return places;
  }

  @override
  Future<List<NearbyBranch>> nearby(double lat, double lng, double km) async {
    nearbyCalls.add((lat, lng, km));
    if (nearbyError != null) throw nearbyError!;
    return nearbyResults;
  }

  List<PlaceHit> searchHits = const [];
  final searches = <(String, bool)>[];
  final savedPois = <String>[];

  @override
  Future<List<PlaceHit>> search(
    String query,
    double lat,
    double lng, {
    bool submit = false,
  }) async {
    searches.add((query, submit));
    return searchHits;
  }

  List<String> coverIds = const [];
  String? currentCover;
  final coverPicks = <String?>[];

  @override
  Future<Uint8List?> restaurantCover(String restaurantId, String cover) async =>
      null;

  @override
  Future<({List<String> covers, String? current})> coverCandidates(
    String restaurantId,
  ) async => (covers: coverIds, current: currentCover);

  @override
  Future<Uint8List?> coverCandidate(String restaurantId, String cover) async =>
      null;

  @override
  Future<void> setRestaurantCover(String restaurantId, String? cover) async {
    coverPicks.add(cover);
    currentCover = cover;
  }

  /// [uploadRestaurantCover] calls: (restaurant, file path).
  final coverUploads = <(String, String)>[];

  @override
  Future<void> uploadRestaurantCover(String restaurantId, String path) async =>
      coverUploads.add((restaurantId, path));

  /// [setRestaurantCoverUrl] calls: (restaurant, photo url).
  final coverUrls = <(String, String)>[];

  @override
  Future<void> setRestaurantCoverUrl(String restaurantId, String url) async =>
      coverUrls.add((restaurantId, url));

  @override
  Future<Place> savePoi(String poiId) async {
    savedPois.add(poiId);
    return saveBranchResult ?? place();
  }

  @override
  Future<Place> saveBranch(String branchId) async {
    if (saveBranchError != null) throw saveBranchError!;
    savedBranches.add(branchId);
    return saveBranchResult ?? place();
  }

  @override
  Future<void> report(ReportDraft draft) async {
    if (reportError != null) throw reportError!;
    reports.add(draft);
  }

  @override
  Future<void> updateNote(String id, String? note) async {
    if (error != null) throw error!;
    notes[id] = note;
  }

  final privates = <String, bool>{};

  @override
  Future<void> setPrivate(String id, bool private) async {
    if (error != null) throw error!;
    privates[id] = private;
  }

  final pins = <(String, double, double)>[];
  final located = <String>[];
  final deletedBranches = <String>[];
  final tidied = <String>[];
  final branchUpdates =
      <
        ({
          String id,
          String? label,
          String? address,
          String? city,
          String? state,
          double? lat,
          double? lng,
          BranchEditScope scope,
        })
      >[];
  final suggested = <String>[];
  final ratingCalls = <(String, int?)>[];
  RatingSummary ratingResult = const RatingSummary();
  Object? ratingError;
  final reviewSaves = <(String, int, String)>[];
  final reviewRemoves = <String>[];
  final reviewVotes = <(String, ReviewVote?)>[];
  final reviewReports = <(String, ReviewReason, String?)>[];
  ReviewPage? reviewPage;
  ReviewVotes voteResult = const ReviewVotes();
  Review? savedReview;
  Object? reviewError;
  BranchSuggestion suggestion = const BranchSuggestion(
    draft: BranchDraft(),
    sources: [],
    aiUsed: false,
    changed: false,
  );

  /// (from, into, name) per merge.
  final merges = <(List<String>, String, String?)>[];

  @override
  Future<void> mergeRestaurants(
    List<String> from,
    String into, {
    String? name,
  }) async => merges.add((from, into, name));

  @override
  Future<({int merged, int removed})> tidyBranches(String restaurantId) async {
    tidied.add(restaurantId);
    return (merged: 1, removed: 1);
  }

  LocateResult locateResult = LocateResult.found;

  @override
  Future<void> setPin(String branchId, double lat, double lng) async =>
      pins.add((branchId, lat, lng));

  @override
  Future<LocateResult> locate(String branchId) async {
    located.add(branchId);
    return locateResult;
  }

  @override
  Future<void> deleteBranch(String branchId) async =>
      deletedBranches.add(branchId);

  @override
  Future<void> updateBranch(
    String branchId, {
    String? label,
    String? address,
    String? city,
    String? state,
    double? lat,
    double? lng,
    BranchEditScope scope = BranchEditScope.personal,
  }) async {
    if (error != null) throw error!;
    branchUpdates.add((
      id: branchId,
      label: label,
      address: address,
      city: city,
      state: state,
      lat: lat,
      lng: lng,
      scope: scope,
    ));
  }

  @override
  Future<BranchSuggestion> suggestBranch(String branchId) async {
    if (error != null) throw error!;
    suggested.add(branchId);
    return suggestion;
  }

  /// [addSiblingBranch] calls: (branch, address, lat).
  final siblings = <(String, String?, double)>[];

  @override
  Future<void> addSiblingBranch(
    String branchId, {
    String? address,
    String? city,
    String? state,
    required double lat,
    required double lng,
  }) async => siblings.add((branchId, address, lat));

  /// What [searchPin] answers; [pinSearches] records (branch, source, q).
  List<PinHit> pinHits = const [];
  final pinSearches = <(String, String, String?)>[];

  @override
  Future<({String query, List<PinHit> hits})> searchPin(
    String branchId,
    String source, {
    String? q,
  }) async {
    if (error != null) throw error!;
    pinSearches.add((branchId, source, q));
    return (query: q ?? 'Shop, Kuala Lumpur', hits: pinHits);
  }

  List<AreaState> areaList = const [
    (name: 'Kelantan', towns: ['Ketereh', 'Kota Bharu']),
    (name: 'Kuala Lumpur', towns: ['Kuala Lumpur', 'Setapak']),
    (name: 'Selangor', towns: ['Kajang', 'Shah Alam']),
  ];

  @override
  Future<List<AreaState>> areas() async => areaList;

  /// What [pinFromMapsLink] answers; set [error] to make it throw.
  MapsPin mapsPin = (
    lat: 3.1994645,
    lng: 101.6956504,
    name: 'Port Lepak Sentul',
  );
  final mapsLinks = <String>[];

  @override
  Future<MapsPin> pinFromMapsLink(String url) async {
    if (error != null) throw error!;
    mapsLinks.add(url);
    return mapsPin;
  }

  @override
  Future<RatingSummary> rateBranch(String branchId, int stars) async {
    if (ratingError != null) throw ratingError!;
    ratingCalls.add((branchId, stars));
    return ratingResult;
  }

  @override
  Future<RatingSummary> clearRating(String branchId) async {
    if (ratingError != null) throw ratingError!;
    ratingCalls.add((branchId, null));
    return ratingResult;
  }

  @override
  Future<({RatingSummary rating, Review? review})> saveReview(
    String branchId,
    int stars,
    String text,
  ) async {
    if (reviewError != null) throw reviewError!;
    reviewSaves.add((branchId, stars, text));
    return (rating: ratingResult, review: savedReview);
  }

  @override
  Future<RatingSummary> removeReview(String branchId) async {
    if (reviewError != null) throw reviewError!;
    reviewRemoves.add(branchId);
    return ratingResult;
  }

  @override
  Future<ReviewPage> reviews(String branchId, {int offset = 0}) async {
    if (reviewError != null) throw reviewError!;
    return reviewPage ??
        ReviewPage(
          branchId: branchId,
          branchName: 'Kedai',
          rating: ratingResult,
          reviews: const [],
        );
  }

  @override
  Future<ReviewVotes> voteReview(String reviewId, ReviewVote? vote) async {
    if (reviewError != null) throw reviewError!;
    reviewVotes.add((reviewId, vote));
    return voteResult;
  }

  @override
  Future<void> reportReview(
    String reviewId,
    ReviewReason reason,
    String? note,
  ) async {
    if (reviewError != null) throw reviewError!;
    reviewReports.add((reviewId, reason, note));
  }

  @override
  Future<void> remove(String id) async {
    if (error != null) throw error!;
    removed.add(id);
  }
}
