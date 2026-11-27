import '../../recipes/domain/recipe.dart';

/// One line on the user's shopping checklist.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.done,
    this.ingredient,
    this.category,
    this.recipes = const [],
    this.products = const [],
    this.pick,
  });

  /// The recipe line's product or brand, copied when the recipe was added; null = none.
  final LinePick? pick;

  final String id;
  final String text;
  final bool done;

  /// The catalogue ingredient (for "see all products"); null for a typed or unrecognised line.
  final String? ingredient;

  /// The ingredient's catalogue section (Sayur, Protein...): the list is grouped by it. null = "Other".
  final String? category;

  /// The recipes the line came from: several when the same ingredient was added up; empty for a typed item.
  final List<({String id, String name})> recipes;

  /// Catalogue products for the line's ingredient: buying hints, not prices or stock.
  final List<ShoppingProduct> products;
}

class ShoppingProduct {
  const ShoppingProduct({
    required this.name,
    this.brand,
    this.manufacturer,
    this.country,
    this.mine = false,
    this.photo,
  });

  /// Its photo id ([CataloguePhoto]); null = none.
  final String? photo;

  final String name;
  final String? brand;
  final String? manufacturer;

  /// Where the brand is from ("Malaysia").
  final String? country;

  /// The user's own brand for this ingredient (Account > Brands).
  final bool mine;
}

/// The user's brand choices: their brand per ingredient, and brands or whole makers they avoid (one of the two
/// set). Private to them, also on a family list.
typedef BrandChoices = ({
  List<({String ingredient, String brand})> mine,
  List<({String? brand, String? maker})> avoid,
});

/// What to avoid: a [brand], or everything from a [maker].
typedef AvoidTarget = ({String? brand, String? maker});
