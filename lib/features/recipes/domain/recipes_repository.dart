import 'dart:typed_data';

import 'recipe.dart';
import 'recipe_variant.dart';

/// The user's imported recipes. Every method throws ApiException (core/network) on failure.
abstract interface class RecipesRepository {
  /// Newest first. [family] = the other family members' family recipes.
  Future<List<Recipe>> list({bool family = false});

  /// Public recipes, newest first, 20 a page; pass the last page's next as [cursor].
  Future<({List<Recipe> recipes, String? next})> community({
    String? query,
    String? cursor,
    int? limit,
  });

  /// The seeded catalogue dishes, by name, a page at a time (cursor = the last page's next).
  Future<({List<Dish> dishes, String? next})> dishes({
    String? query,
    String? cursor,
    int? limit,
  });

  /// "Make my copy": the caller's own, editable copy.
  Future<RecipeDetail> copy(String id);

  /// The owner's choice. public needs a name (409 name_required); family needs a family.
  Future<RecipeDetail> setVisibility(String id, RecipeVisibility visibility);

  /// Reasons: copyright, spam, offensive, wrong_info, other.
  Future<void> report(String id, String reason, {String? note});

  Future<RecipeDetail> get(String id);

  /// Other web recipes for a catalogue dish, best match first (empty until the owner finds them).
  Future<List<RecipeVariant>> variants(String id);

  /// Takes the recipe off this user's book.
  Future<void> delete(String id);

  /// Catalogue ingredient names matching [query] (2+ characters).
  Future<List<String>> searchIngredients(String query);

  /// Links ingredient line [index] to the catalogue ingredient [name] (null = unlink); returns the updated recipe.
  Future<RecipeDetail> linkIngredient(String id, int index, String? name);

  /// A recipe typed from scratch (one line per ingredient and per step); returns it.
  Future<RecipeDetail> create({
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  });

  /// The owner's photo from a local jpeg/png/webp file (5 MB max); returns the recipe with its new cover.
  Future<RecipeDetail> setCover(String id, String path);

  Future<void> removeCover(String id);

  /// The photo's bytes; null = none. [cover] is the recipe's cover id (a new one per upload, so a cache never goes stale).
  Future<Uint8List?> cover(String id, String cover);

  /// Replaces the name, ingredient lines and steps; returns the saved recipe.
  Future<RecipeDetail> edit(
    String id, {
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  });
}
