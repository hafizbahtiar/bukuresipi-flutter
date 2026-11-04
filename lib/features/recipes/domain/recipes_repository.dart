import 'recipe.dart';

/// The user's imported recipes. Every method throws ApiException (core/network) on failure.
abstract interface class RecipesRepository {
  /// Newest first.
  Future<List<Recipe>> list();

  Future<RecipeDetail> get(String id);

  /// Takes the recipe off this user's book.
  Future<void> delete(String id);
}
