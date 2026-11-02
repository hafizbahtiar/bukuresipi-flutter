import 'recipe.dart';

/// The user's imported recipes. Every method throws ApiException (core/network) on failure.
abstract interface class RecipesRepository {
  /// Newest first.
  Future<List<Recipe>> list();

  Future<RecipeDetail> get(String id);
}
