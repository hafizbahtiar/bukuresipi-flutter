import 'recipe.dart';

/// The user's imported recipes. Every method throws ApiException (core/network) on failure.
abstract interface class RecipesRepository {
  /// Newest first.
  Future<List<Recipe>> list();

  Future<RecipeDetail> get(String id);

  /// Takes the recipe off this user's book.
  Future<void> delete(String id);

  /// Catalogue ingredient names matching [query] (2+ characters).
  Future<List<String>> searchIngredients(String query);

  /// Links ingredient line [index] to the catalogue ingredient [name] (null = unlink); returns the updated recipe.
  Future<RecipeDetail> linkIngredient(String id, int index, String? name);

  /// Replaces the name, ingredient lines and steps; returns the saved recipe.
  Future<RecipeDetail> edit(
    String id, {
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  });
}
