import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/shopping.dart';
import '../domain/shopping_repository.dart';

/// The shopping checklist for the Shopping tab and the recipe page's "add to list". Actions throw ApiException.
class ShoppingController extends ChangeNotifier {
  ShoppingController(this._repo);

  final ShoppingRepository _repo;
  List<ShoppingItem> _items = const [];
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
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    final generation = _generation;
    _loading = true;
    notifyListeners();
    try {
      final items = await _repo.list();
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
    await _repo.addText(text);
    await load();
  }

  /// How many lines were added (0 = all already on the list).
  Future<int> addRecipe(String recipeId) async {
    final added = await _repo.addRecipe(recipeId);
    await load();
    return added.length;
  }

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
    await _repo.clearDone();
    _items = _items.where((i) => !i.done).toList();
    notifyListeners();
  }
}
