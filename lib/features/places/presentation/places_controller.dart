import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/nearby_branch.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';
import '../domain/rating.dart';
import '../domain/report.dart';
import '../domain/review.dart';

/// The user's places for the Book list, the map and the detail page. Kept after a failed reload (shown with [error]).
class PlacesController extends ChangeNotifier {
  PlacesController(this._repo);

  final PlacesRepository _repo;
  List<Place> _places = const [];
  bool _loading = false;
  int _generation = 0;
  bool _loaded = false;
  String? _error;

  List<Place> get places => _places;
  List<Place> get pinned => _places.where((p) => p.pins.isNotEmpty).toList();
  List<Place> get unpinned => _places.where((p) => p.pins.isEmpty).toList();
  bool get loading => _loading;

  /// False until the first load finished (empty list vs. not loaded yet).
  bool get loaded => _loaded;

  /// ApiException code of the last failed load.
  String? get error => _error;

  Place? byId(String id) => _places.where((p) => p.id == id).firstOrNull;

  /// Sign-out: the next user must never see these.
  void clear() {
    _generation++; // a load still in flight belongs to the previous user: drop its answer
    _loading = false;
    _places = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    final generation = _generation;
    _loading = true;
    notifyListeners();
    try {
      final list = await _repo.list();
      if (generation != _generation) return;
      _places = list;
      _error = null;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      _error = e.code;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _loaded = true;
        notifyListeners();
      }
    }
  }

  /// Throws ApiException; the screen shows it.
  Future<void> updateNote(String id, String? note) async {
    await _repo.updateNote(id, note);
    final trimmed = note?.trim();
    _places = [
      for (final p in _places)
        p.id == id
            ? p.copyWith(
                note: trimmed == null || trimmed.isEmpty ? null : trimmed,
              )
            : p,
    ];
    notifyListeners();
  }

  /// Throws ApiException; the screen shows it.
  Future<void> setPrivate(String id, bool private) async {
    await _repo.setPrivate(id, private);
    _places = [
      for (final p in _places) p.id == id ? p.copyWith(private: private) : p,
    ];
    notifyListeners();
  }

  /// Throws ApiException. The branch's pin is the server's call (earliest hand pin), so reload.
  Future<void> setPin(String branchId, double lat, double lng) async {
    await _repo.setPin(branchId, lat, lng);
    await load();
  }

  /// Throws ApiException. A found pin reloads the places.
  Future<LocateResult> locate(String branchId) async {
    final result = await _repo.locate(branchId);
    if (result == LocateResult.found) await load();
    return result;
  }

  /// Owner only. Throws ApiException.
  Future<({int merged, int removed})> tidyBranches(String restaurantId) async {
    final done = await _repo.tidyBranches(restaurantId);
    await load();
    return done;
  }

  /// Owner only. Throws ApiException.
  Future<void> deleteBranch(String branchId) async {
    await _repo.deleteBranch(branchId);
    await load();
  }

  /// Throws ApiException; reloads the places so the caller's screens see the personal or shared edit.
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
    await _repo.updateBranch(
      branchId,
      label: label,
      address: address,
      city: city,
      state: state,
      lat: lat,
      lng: lng,
      scope: scope,
    );
    await load();
  }

  /// Owner only. Throws ApiException; the edit sheet shows the draft for review.
  Future<BranchSuggestion> suggestBranch(String branchId) =>
      _repo.suggestBranch(branchId);

  Future<List<AreaState>>? _areas;

  /// The states and towns, asked once per app run (they change only with a server migration); a failure asks again.
  Future<List<AreaState>> areas() =>
      _areas ??= _repo.areas().catchError((Object e) {
        _areas = null;
        throw e;
      });

  /// A pasted Google Maps link -> its pin, for the edit form. Throws ApiException.
  Future<MapsPin> pinFromMapsLink(String url) => _repo.pinFromMapsLink(url);

  Future<({String query, List<PinHit> hits})> searchPin(
    String branchId,
    String source, {
    String? q,
  }) => _repo.searchPin(branchId, source, q: q);

  /// Rates or clears (`stars == null`) a branch, then replaces its summary in memory without a full reload.
  Future<RatingSummary> setRating(String branchId, int? stars) async {
    try {
      final rating = stars == null
          ? await _repo.clearRating(branchId)
          : await _repo.rateBranch(branchId, stars);
      _replaceRating(branchId, rating);
      return rating;
    } on ApiException catch (e) {
      // The branch was merged/deleted, or the caller unsaved elsewhere: refresh the truth.
      if (e.code == 'not_saved' || e.code == 'not_found') await load();
      rethrow;
    }
  }

  void _replaceRating(String branchId, RatingSummary rating) {
    _places = [
      for (final place in _places)
        place.copyWith(
          branches: [
            for (final branch in place.branches)
              branch.id == branchId ? branch.copyWith(rating: rating) : branch,
          ],
        ),
    ];
    notifyListeners();
  }

  Future<({RatingSummary rating, Review? review})> saveReview(
    String branchId,
    int stars,
    String text,
  ) async {
    final result = await _repo.saveReview(branchId, stars, text);
    _replaceRating(branchId, result.rating);
    return result;
  }

  Future<RatingSummary> removeReview(String branchId) async {
    final rating = await _repo.removeReview(branchId);
    _replaceRating(branchId, rating);
    return rating;
  }

  Future<ReviewPage> reviews(String branchId, {int offset = 0}) =>
      _repo.reviews(branchId, offset: offset);

  Future<ReviewVotes> voteReview(String reviewId, ReviewVote? vote) =>
      _repo.voteReview(reviewId, vote);

  Future<void> reportReview(
    String reviewId,
    ReviewReason reason,
    String? note,
  ) => _repo.reportReview(reviewId, reason, note);

  /// Throws ApiException; the screen shows it.
  Future<void> remove(String id) async {
    await _repo.remove(id);
    _places = _places.where((p) => p.id != id).toList();
    notifyListeners();
  }

  /// Throws ApiException; the map keeps its last result.
  Future<List<NearbyBranch>> nearby(double lat, double lng, double km) =>
      _repo.nearby(lat, lng, km);

  /// Saves a branch's restaurant, then reloads the saved places for the map.
  Future<Place> saveBranch(String branchId) async {
    final place = await _repo.saveBranch(branchId);
    await load();
    return place;
  }

  /// Throws ApiException.
  Future<List<PlaceHit>> search(
    String query,
    double lat,
    double lng, {
    bool submit = false,
  }) => _repo.search(query, lat, lng, submit: submit);

  /// Saves a search result not in the app yet, then reloads the saved places for the map.
  Future<Place> savePoi(String poiId) async {
    final place = await _repo.savePoi(poiId);
    await load();
    return place;
  }

  /// Throws ApiException; the sheet shows it.
  Future<void> report(ReportDraft draft) => _repo.report(draft);

  /// The restaurant's cover photo bytes, or null (none, or not loaded).
  Future<Uint8List?> restaurantCover(String restaurantId, String cover) =>
      _repo.restaurantCover(restaurantId, cover);

  /// Owner only. Throws ApiException.
  Future<({List<String> covers, String? current})> coverCandidates(
    String restaurantId,
  ) => _repo.coverCandidates(restaurantId);

  /// Owner only.
  Future<Uint8List?> coverCandidate(String restaurantId, String cover) =>
      _repo.coverCandidate(restaurantId, cover);

  /// Owner only: sets the cover for everyone, then reloads the saved places so the new id shows.
  Future<void> setRestaurantCover(String restaurantId, String? cover) async {
    await _repo.setRestaurantCover(restaurantId, cover);
    await load();
  }
}
