/// One line on the user's shopping checklist.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.done,
    this.ingredient,
    this.recipes = const [],
    this.products = const [],
  });

  final String id;
  final String text;
  final bool done;

  /// The catalogue ingredient (for "see all products"); null for a typed or unrecognised line.
  final String? ingredient;

  /// The recipes the line came from: several when the same ingredient was added up; empty for a typed item.
  final List<({String id, String name})> recipes;

  /// Catalogue products for the line's ingredient: buying hints, not prices or stock.
  final List<ShoppingProduct> products;
}

class ShoppingProduct {
  const ShoppingProduct({required this.name, this.brand, this.manufacturer});

  final String name;
  final String? brand;
  final String? manufacturer;
}
