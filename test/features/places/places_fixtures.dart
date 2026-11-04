import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/places_repository.dart';
import 'package:bukuresipi_flutter/features/places/domain/report.dart';

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
  BranchSuggestion suggestion = const BranchSuggestion(
    draft: BranchDraft(),
    sources: [],
    aiUsed: false,
    changed: false,
  );

  @override
  Future<({int merged, int removed})> tidyBranches(String restaurantId) async {
    tidied.add(restaurantId);
    return (merged: 1, removed: 1);
  }

  bool locateFinds = true;

  @override
  Future<void> setPin(String branchId, double lat, double lng) async =>
      pins.add((branchId, lat, lng));

  @override
  Future<bool> locate(String branchId) async {
    located.add(branchId);
    return locateFinds;
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

  @override
  Future<void> remove(String id) async {
    if (error != null) throw error!;
    removed.add(id);
  }
}
