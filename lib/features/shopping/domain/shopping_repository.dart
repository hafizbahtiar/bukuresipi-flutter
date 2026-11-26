import 'shopping.dart';

/// The user's shopping checklist (/shopping). Every method throws ApiException (core/network) on failure.
abstract interface class ShoppingRepository {
  /// Still to buy first, then bought; oldest first in each. [family] = the family list (any member changes it).
  Future<List<ShoppingItem>> list({bool family = false});

  /// Returns what was added. A recipe adds only its lines not already on the list.
  Future<List<ShoppingItem>> addText(String text, {bool family = false});

  /// [skipOptional] leaves the recipe's optional lines out; [have] = ingredient names the user has (left out);
  /// [servings] = the recipe page's "Serves N" when changed (number amounts scaled from the recipe's own).
  Future<List<ShoppingItem>> addRecipe(
    String recipeId, {
    bool family = false,
    bool skipOptional = false,
    List<String> have = const [],
    bool staples = false,
    int? servings,
  });

  /// Catalogue ingredient names for what the user is typing (2+ characters), names starting with it first.
  Future<List<String>> suggest(String query);

  Future<ShoppingItem> setDone(String id, bool done);
  Future<void> delete(String id);

  /// Removes every bought line of that list.
  Future<void> clearDone({bool family = false});

  /// Catalogue products of one ingredient in the user's order (their brand first, avoided left out; up to 50).
  Future<List<ShoppingProduct>> products(String ingredient);

  Future<BrandChoices> brandChoices();

  /// [brand] becomes the user's for [ingredient] (off the avoid list if it was there). Throws ApiException
  /// (maker_avoided when the user avoids its whole maker).
  Future<void> setMyBrand(String ingredient, String brand);
  Future<void> clearMyBrand(String ingredient);

  /// Drops the user's brand choices it covers. Throws ApiException (avoid_full at 100).
  Future<void> avoid(AvoidTarget target);
  Future<void> unavoid(AvoidTarget target);
}
