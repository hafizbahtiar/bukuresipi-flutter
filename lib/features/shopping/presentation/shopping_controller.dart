import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/shopping.dart';
import '../domain/shopping_repository.dart';

/// The shopping checklist for the Shopping tab and the recipe page's "add to list". Actions throw ApiException.
class ShoppingController extends ChangeNotifier {
  ShoppingController(this._repo);

  final ShoppingRepository _repo;
  bool _family = false;

  /// Which list the add-recipe action used last; null = not asked yet (the recipe page asks once).
  // shortcut: remembered for the session only; keep it in SharedPreferences if people ask every launch.
  bool? lastRecipeList;
  List<ShoppingItem> _items = const [];

  /// The Shopping tab shows the family list (only offered in a family).
  bool get family => _family;

  /// Switch the tab's list; the other one loads.
  Future<void> show({required bool family}) async {
    if (family == _family) return;
    _family = family;
    _generation++; // the other list's answer must not land here
    _loading = false;
    _items = const [];
    _loaded = false;
    notifyListeners();
    await load();
  }

  bool _loading = false;
  bool _loaded = false;
  int _generation = 0;
  String? _error;

  List<ShoppingItem> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;

  /// ApiException code of the last failed load.
  String? get error => _error;
  bool get anyDone => _items.any((i) => i.done);

  void clear() {
    _generation++; // a load still in flight belongs to the previous user: drop its answer
    _loading = false;
    _loaded = false;
    _items = const [];
    _error = null;
    _family = false;
    lastRecipeList = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    final generation = _generation;
    _loading = true;
    notifyListeners();
    try {
      final items = await _repo.list(family: _family);
      if (generation != _generation) return;
      _items = items;
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

  // The server's order (to buy first) is kept by reloading after changes that move lines.
  Future<void> addText(String text) async {
    await _repo.addText(text, family: _family);
    await load();
  }

  /// How many lines were added (0 = all already on the list). [family] = to the family list.
  Future<int> addRecipe(String recipeId, {bool family = false}) async {
    final added = await _repo.addRecipe(recipeId, family: family);
    lastRecipeList = family;
    if (family == _family) await load();
    return added.length;
  }

  /// Throws ApiException; the field shows nothing then.
  Future<List<String>> suggest(String query) => _repo.suggest(query);

  Future<void> setDone(String id, bool done) async {
    await _repo.setDone(id, done);
    await load();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    _items = _items.where((i) => i.id != id).toList();
    notifyListeners();
  }

  /// Throws ApiException.
  Future<List<ShoppingProduct>> products(String ingredient) =>
      _repo.products(ingredient);

  Future<void> clearDone() async {
    await _repo.clearDone(family: _family);
    _items = _items.where((i) => !i.done).toList();
    notifyListeners();
  }
}
