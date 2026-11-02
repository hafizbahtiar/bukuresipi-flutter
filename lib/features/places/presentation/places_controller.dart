import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';

/// The user's places for the Book list, the map and the detail page. Kept after a failed reload (shown with [error]).
class PlacesController extends ChangeNotifier {
  PlacesController(this._repo);

  final PlacesRepository _repo;
  List<Place> _places = const [];
  bool _loading = false;
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
    _places = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _places = await _repo.list();
      _error = null;
    } on ApiException catch (e) {
      _error = e.code;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
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

  /// Throws ApiException. The branch's pin is the server's call (earliest hand pin), so reload.
  Future<void> setPin(String branchId, double lat, double lng) async {
    await _repo.setPin(branchId, lat, lng);
    await load();
  }

  /// true = found and pinned. Throws ApiException.
  Future<bool> locate(String branchId) async {
    final found = await _repo.locate(branchId);
    if (found) await load();
    return found;
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

  /// Throws ApiException; the screen shows it.
  Future<void> remove(String id) async {
    await _repo.remove(id);
    _places = _places.where((p) => p.id != id).toList();
    notifyListeners();
  }
}
