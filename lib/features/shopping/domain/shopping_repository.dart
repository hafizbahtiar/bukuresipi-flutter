import 'shopping.dart';

/// The user's shopping checklist (/shopping). Every method throws ApiException (core/network) on failure.
abstract interface class ShoppingRepository {
  /// Still to buy first, then bought; oldest first in each. [family] = the family list (any member changes it).
  Future<List<ShoppingItem>> list({bool family = false});

  /// Returns what was added. A recipe adds only its lines not already on the list.
  Future<List<ShoppingItem>> addText(String text, {bool family = false});

  /// [skipOptional] leaves the recipe's optional lines out.
  Future<List<ShoppingItem>> addRecipe(
    String recipeId, {
    bool family = false,
    bool skipOptional = false,
  });

  /// Catalogue ingredient names for what the user is typing (2+ characters), names starting with it first.
  Future<List<String>> suggest(String query);

  Future<ShoppingItem> setDone(String id, bool done);
  Future<void> delete(String id);

  /// Removes every bought line of that list.
  Future<void> clearDone({bool family = false});

  /// Catalogue products of one ingredient (branded first, up to 50).
  Future<List<ShoppingProduct>> products(String ingredient);
}
