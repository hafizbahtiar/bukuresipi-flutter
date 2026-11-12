import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/recipe_variant.dart';
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

  List<Recipe> _family = const [];

  List<Recipe> get recipes => _recipes;

  /// The other family members' family recipes (empty outside a family).
  List<Recipe> get familyRecipes => _family;
  bool get loading => _loading;

  /// False until the first load finished (empty list vs. not loaded yet).
  bool get loaded => _loaded;

  /// ApiException code of the last failed load.
  String? get error => _error;

  /// The last recipe saved by the edit page: lists kept outside this controller (Home's cards) patch their copy.
  final edited = ValueNotifier<RecipeDetail?>(null);

  /// The last recipe or dish deleted: Home's cards drop it.
  final removed = ValueNotifier<String?>(null);

  Recipe? byId(String id) => _recipes.where((r) => r.id == id).firstOrNull;

  void clear() {
    _generation++; // a load still in flight belongs to the previous user: drop its answer
    _loading = false;
    _recipes = const [];
    _family = const [];
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
      final (list, family) = await (
        _repo.list(),
        _repo.list(family: true),
      ).wait;
      if (generation != _generation) return;
      _recipes = list;
      _family = family;
      _error = null;
    } on ParallelWaitError<
      (List<Recipe>?, List<Recipe>?),
      (AsyncError?, AsyncError?)
    > catch (e) {
      if (generation != _generation) return;
      if (e.values.$1 case final list?) {
        _recipes = list; // the family list failing never hides the user's own
      }
      // Only the user's own list sets error; a failed family list shows on the next load.
      final err = e.errors.$1?.error;
      _error = err == null
          ? null
          : (err is ApiException ? err.code : 'unknown');
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

  /// The owner's photo: [path] = a local image file; returns the recipe with its new cover.
  Future<RecipeDetail> setCover(String id, String path) async {
    final saved = await _repo.setCover(id, path);
    unawaited(load());
    return saved;
  }

  Future<void> removeCover(String id) async {
    await _repo.removeCover(id);
    unawaited(load());
  }

  Future<Uint8List?> cover(String id, String cover) => _repo.cover(id, cover);

  Future<List<RecipeVariant>> variants(String id) => _repo.variants(id);

  Future<List<String>> searchIngredients(String query) =>
      _repo.searchIngredients(query);

  /// Throws ApiException.
  Future<RecipeDetail> linkIngredient(String id, int index, String? name) =>
      _repo.linkIngredient(id, index, name);

  /// Throws ApiException. The book list is reloaded: the name or counts may have changed.
  Future<RecipeDetail> create({
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) async {
    final saved = await _repo.create(
      name: name,
      ingredients: ingredients,
      steps: steps,
    );
    unawaited(load());
    return saved;
  }

  Future<RecipeDetail> edit(
    String id, {
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) async {
    final saved = await _repo.edit(
      id,
      name: name,
      ingredients: ingredients,
      steps: steps,
    );
    unawaited(load());
    return saved;
  }

  /// Throws ApiException.
  Future<({List<Recipe> recipes, String? next})> community({
    String? query,
    String? cursor,
    int? limit,
  }) => _repo.community(query: query, cursor: cursor, limit: limit);

  /// Throws ApiException.
  Future<({List<Dish> dishes, String? next})> dishes({
    String? query,
    String? cursor,
    int? limit,
  }) => _repo.dishes(query: query, cursor: cursor, limit: limit);

  /// Throws ApiException. The copy is the user's: their list is reloaded.
  Future<RecipeDetail> copy(String id) async {
    final copy = await _repo.copy(id);
    unawaited(load());
    return copy;
  }

  /// Throws ApiException (name_required, not_in_family).
  Future<RecipeDetail> setVisibility(
    String id,
    RecipeVisibility visibility,
  ) async {
    final saved = await _repo.setVisibility(id, visibility);
    unawaited(load());
    return saved;
  }

  /// Throws ApiException.
  Future<void> report(String id, String reason, {String? note}) =>
      _repo.report(id, reason, note: note);

  /// Throws ApiException; the detail page shows it.
  Future<void> remove(String id) async {
    await _repo.delete(id);
    removed.value = id;
    _recipes = _recipes.where((r) => r.id != id).toList();
    notifyListeners();
  }
}
