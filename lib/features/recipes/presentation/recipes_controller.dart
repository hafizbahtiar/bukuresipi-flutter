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
    _recipes = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _recipes = await _repo.list();
      _error = null;
    } on ApiException catch (e) {
      _error = e.code;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Throws ApiException; the detail page shows it.
  Future<RecipeDetail> detail(String id) => _repo.get(id);
}
