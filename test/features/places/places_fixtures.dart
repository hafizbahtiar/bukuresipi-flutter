import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/places_repository.dart';

const placeJson = {
  'id': 'p-1',
  'note': 'Dishes: Ayam goreng',
  'createdAt': '2026-11-02 12:00:00',
  'branchId': 'b-2',
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
}) => Place(
  id: id,
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

class FakePlaces implements PlacesRepository {
  List<Place> places = [];
  Object? error;
  final removed = <String>[];
  final notes = <String, String?>{};

  @override
  Future<List<Place>> list() async {
    if (error != null) throw error!;
    return places;
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
  Future<void> remove(String id) async {
    if (error != null) throw error!;
    removed.add(id);
  }
}
