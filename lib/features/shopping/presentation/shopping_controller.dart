import 'dart:async';

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
    _pending = 0;
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
    _pending = 0;
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
      if (_pending == 0) {
        _items =
            items; // else a save is still landing: its sync brings the list
      }
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

  // Changes show at once (optimistic) and are saved behind; a failed save puts that one change back and throws.
  // While saves are in flight nothing reloads; when the last one lands, one quiet reload brings the server's sums
  // and order (to buy first). So rows never jump under a finger ticking several lines.
  int _pending = 0;
  int _localIds = 0;
  final _aliases = <String, String>{};

  /// A stable key for a row: an added line keeps the key it had before the server gave it an id (no re-animation).
  String keyOf(ShoppingItem item) => _aliases[item.id] ?? item.id;

  /// A line typed here that the server has not saved yet: it cannot be ticked or removed until then.
  bool isLocal(ShoppingItem item) => item.id.startsWith('local-');

  Future<T> _save<T>(
    Future<T> Function() call, {
    required void Function() undo,
  }) async {
    final generation = _generation;
    _pending++;
    try {
      return await call();
    } catch (_) {
      if (generation == _generation) {
        undo();
        notifyListeners();
      }
      rethrow;
    } finally {
      if (generation == _generation && --_pending == 0) unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    final generation = _generation;
    try {
      final items = await _repo.list(family: _family);
      if (generation != _generation || _pending > 0) {
        return; // a newer change will sync again
      }
      _items = items;
      _error = null;
      notifyListeners();
    } on ApiException {
      // Kept as shown; the next pull-to-refresh or reload fixes it.
    }
  }

  void _replace(String id, ShoppingItem Function(ShoppingItem) change) {
    _items = [for (final i in _items) i.id == id ? change(i) : i];
  }

  Future<void> addText(String text) async {
    final local = ShoppingItem(
      id: 'local-${_localIds++}',
      text: text,
      done: false,
    );
    // After the last line still to buy (a just-ticked line stays in place until the sync moves it).
    final at = _items.lastIndexWhere((i) => !i.done) + 1;
    _items = [..._items.take(at), local, ..._items.skip(at)];
    notifyListeners();
    final saved = await _save(
      () => _repo.addText(text, family: _family),
      undo: () => _items = _items.where((i) => i.id != local.id).toList(),
    );
    if (saved.isEmpty || !_items.any((i) => i.id == local.id)) return;
    _aliases[saved.first.id] = local.id;
    _items = [
      for (final i in _items)
        if (i.id == local.id) ...saved else i,
    ];
    notifyListeners();
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
    ShoppingItem flip(ShoppingItem i, bool d) => ShoppingItem(
      id: i.id,
      text: i.text,
      done: d,
      ingredient: i.ingredient,
      recipes: i.recipes,
      products: i.products,
    );
    _replace(id, (i) => flip(i, done));
    notifyListeners();
    await _save(
      () => _repo.setDone(id, done),
      undo: () => _replace(id, (i) => flip(i, !done)),
    );
  }

  Future<void> remove(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    _items = [..._items]..removeAt(index);
    notifyListeners();
    await _save(
      () => _repo.delete(id),
      undo: () =>
          _items = [..._items]..insert(index.clamp(0, _items.length), item),
    );
  }

  /// Throws ApiException.
  Future<List<ShoppingProduct>> products(String ingredient) =>
      _repo.products(ingredient);

  Future<void> clearDone() async {
    final done = _items.where((i) => i.done).toList();
    _items = _items.where((i) => !i.done).toList();
    notifyListeners();
    await _save(
      () => _repo.clearDone(family: _family),
      undo: () => _items = [..._items, ...done],
    );
  }
}
