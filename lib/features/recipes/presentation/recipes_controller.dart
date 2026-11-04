import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/recipe.dart';
import '../domain/recipes_repository.dart';

/// The user's imported recipes for the book. Kept after a failed reload (shown with [error]).
class RecipesController extends ChangeNotifier {
  RecipesController(this._repo);

  final RecipesRepository _repo;
  List<Recipe> _recipes = const [];
  bool _loading = false;
  int _generation = 0;
  bool _loaded = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  bool get loading => _loading;

  /// False until the first load finished (empty list vs. not loaded yet).
  bool get loaded => _loaded;

  /// ApiException code of the last failed load.
  String? get error => _error;

  Recipe? byId(String id) => _recipes.where((r) => r.id == id).firstOrNull;

  void clear() {
    _generation++; // a load still in flight belongs to the previous user: drop its answer
    _loading = false;
    _recipes = const [];
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
      _recipes = list;
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

  /// Throws ApiException; the detail page shows it.
  Future<RecipeDetail> detail(String id) => _repo.get(id);

  /// Throws ApiException; the detail page shows it.
  Future<void> remove(String id) async {
    await _repo.delete(id);
    _recipes = _recipes.where((r) => r.id != id).toList();
    notifyListeners();
  }
}
