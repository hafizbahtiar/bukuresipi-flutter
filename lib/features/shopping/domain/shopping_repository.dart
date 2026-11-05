import 'shopping.dart';

/// The user's shopping checklist (/shopping). Every method throws ApiException (core/network) on failure.
abstract interface class ShoppingRepository {
  /// Still to buy first, then bought; oldest first in each.
  Future<List<ShoppingItem>> list();

  /// Returns what was added. A recipe adds only its lines not already on the list.
  Future<List<ShoppingItem>> addText(String text);
  Future<List<ShoppingItem>> addRecipe(String recipeId);

  Future<ShoppingItem> setDone(String id, bool done);
  Future<void> delete(String id);

  /// Removes every bought line.
  Future<void> clearDone();

  /// Catalogue products of one ingredient (branded first, up to 50).
  Future<List<ShoppingProduct>> products(String ingredient);
}
