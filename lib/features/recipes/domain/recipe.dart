/// Who sees a recipe: only its owner, their family, or everyone (community).
enum RecipeVisibility {
  private,
  family,
  public;

  static RecipeVisibility parse(Object? v) =>
      values.where((x) => x.name == v).firstOrNull ?? RecipeVisibility.private;
}

/// A recipe's owner as other users see it. null on a recipe = a catalogue dish.
class RecipeOwner {
  const RecipeOwner({required this.name, required this.isMe});

  final String? name;
  final bool isMe;
}

/// A recipe the user shared into Bukuresipi (or a family member's / a community one).
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sourceUrl,
    this.missing = const [],
    this.ingredientCount = 0,
    this.stepCount = 0,
    this.visibility = RecipeVisibility.private,
    this.owner,
    this.shareId,
    this.cover,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// The share it came from: its photo is the list thumbnail (none = no photo).
  final String? shareId;

  /// The owner's own photo (RecipesRepository.cover); shown before the share's. Changes on every upload.
  final String? cover;
  final RecipeVisibility visibility;
  final RecipeOwner? owner;

  /// The post it came from; opens the video.
  final String? sourceUrl;

  /// 'name' | 'ingredients' | 'steps': what the post did not give.
  final List<String> missing;
  final int ingredientCount;
  final int stepCount;

  /// After an edit: the card's name and photo from the saved recipe.
  Recipe edited(RecipeDetail d) => Recipe(
    id: id,
    name: d.name,
    createdAt: createdAt,
    sourceUrl: sourceUrl,
    missing: missing,
    ingredientCount: ingredientCount,
    stepCount: stepCount,
    visibility: visibility,
    owner: owner,
    shareId: shareId,
    cover: d.cover,
  );
}

/// The credit a shared recipe shows: the post's link, or what it was made from.
enum RecipeSourceType { link, screenshot, typed, catalogue }

/// A seeded catalogue dish (no owner, no steps): read, shopped, or copied.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    this.category,
    this.ingredientCount = 0,
    this.cover,
  });

  final String id;
  final String name;
  final String? category;
  final int ingredientCount;

  /// The owner's photo id (GET /recipes/:id/cover); null = none.
  final String? cover;

  /// After an owner edit: the card's name and photo from the saved dish.
  Dish edited(RecipeDetail d) => Dish(
    id: id,
    name: d.name,
    category: category,
    ingredientCount: ingredientCount,
    cover: d.cover,
  );
}

class RecipeDetail {
  const RecipeDetail({
    required this.id,
    required this.name,
    required this.createdAt,
    this.visibility = RecipeVisibility.private,
    this.owner,
    this.canEdit = true,
    this.hidden = false,
    this.sourceType = RecipeSourceType.typed,
    this.platform,
    this.sourceUrl,
    this.shareId,
    this.cover,
    this.missing = const [],
    this.servings,
    required this.ingredients,
    required this.steps,
    this.allergens = const [],
    this.uncheckedIngredients = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final RecipeVisibility visibility;
  final RecipeOwner? owner;

  /// Only the owner edits, removes or links lines; others view, shop or make a copy.
  final bool canEdit;

  /// The app owner hid it from the community (only its owner sees this).
  final bool hidden;
  final RecipeSourceType sourceType;

  /// 'tiktok' | 'instagram' | ... for a link source.
  final String? platform;
  final String? sourceUrl;

  /// The share it was imported from: its screenshot or post thumbnail (ShareRepository.image).
  final String? shareId;

  /// The owner's own photo (RecipesRepository.cover); shown before the share's. Changes on every upload.
  final String? cover;
  final List<String> missing;

  /// How many people it is for (the post's own words, or the owner's); null = not said, nothing scales.
  final int? servings;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  /// Label-required allergen groups of the recognised ingredients (usual recipe; products differ). Empty is NOT
  /// "allergen free": [uncheckedIngredients] lines were never checked.
  final List<RecipeAllergen> allergens;
  final int uncheckedIngredients;
}

class RecipeAllergen {
  const RecipeAllergen({
    required this.name,
    required this.ingredients,
    this.optionalOnly = false,
  });

  final String name;
  final List<String> ingredients;

  /// Every line it comes from is optional: "only if you add it". Still shown: an allergen never goes quiet.
  final bool optionalOnly;
}

class RecipeIngredient {
  const RecipeIngredient({
    this.name,
    this.rawText,
    this.quantity,
    this.unit,
    this.optional = false,
  });

  /// "If you like": the dish is still the dish without it (the post said so, or the owner marked it).
  final bool optional;

  /// The catalogue name when matched; null = the line is shown as written.
  final String? name;
  final String? rawText;
  final String? quantity;
  final String? unit;

  String get label => name ?? rawText ?? '';

  /// "500 g", or null when the post gave no amount. [factor]: for more or fewer people (see [scaleQuantity]).
  String? amount([double factor = 1]) {
    final parts = [
      scaleQuantity(quantity, factor),
      unit,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class RecipeStep {
  const RecipeStep({required this.stepNo, required this.instruction});

  final int stepNo;
  final String instruction;
}

/// One recipe for "What can I cook?": [have] of [required] lines in the kitchen; [missing] = catalogue names to buy;
/// [unknown] = lines with no catalogue link, as written (to check by eye). Empty [missing] = cook now.
typedef PantryMatch = ({
  Recipe recipe,
  int have,
  int required,
  List<String> missing,
  List<String> unknown,
});

/// A dish AI named for ingredients no recipe fits: a name only; [uses] = the user's own ingredients it takes.
typedef DishSuggestion = ({String name, List<String> uses});

const _glyphs = {'½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3};

/// One amount as written: "2", "1.5", "1/2", "1 1/2", "1½"; null = words ("secukupnya") or anything else.
double? _amountOf(String s) {
  final tokens = s.trim().replaceAll(',', '.').split(RegExp(r'\s+'));
  if (tokens.isEmpty || tokens.length > 2) return null;
  var total = 0.0;
  for (final t in tokens) {
    final m = RegExp(r'^(\d+(?:\.\d+)?)?([½¼¾⅓⅔])?$').firstMatch(t);
    final f = RegExp(r'^(\d+)/(\d+)$').firstMatch(t);
    if (f != null && int.parse(f[2]!) > 0) {
      total += int.parse(f[1]!) / int.parse(f[2]!);
    } else if (m != null && (m[1] != null || m[2] != null)) {
      total += (m[1] == null ? 0 : double.parse(m[1]!)) + (_glyphs[m[2]] ?? 0);
    } else {
      return null;
    }
  }
  return total;
}

/// A cook's number: whole, or a whole and ½ ¼ ¾ when that close; past 10, whole.
String _cookNumber(double x) {
  if (x >= 10) return x.round().toString();
  final quarters = (x * 4).round();
  if ((x * 4 - quarters).abs() < 0.08 && quarters > 0) {
    final whole = quarters ~/ 4;
    final part = const ['', '¼', '½', '¾'][quarters % 4];
    return whole == 0 ? part : '$whole$part';
  }
  return x.toStringAsFixed(1);
}

/// [quantity] for [factor] times the people. Numbers, fractions and ranges ("3-4") scale; words stay as written.
String? scaleQuantity(String? quantity, double factor) {
  if (quantity == null || factor == 1) return quantity;
  final parts = quantity.trim().split(RegExp(r'\s*[-–]\s*'));
  final amounts = [for (final p in parts) _amountOf(p)];
  if (amounts.any((a) => a == null)) return quantity;
  return [for (final a in amounts) _cookNumber(a! * factor)].join('-');
}
