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
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  /// Label-required allergen groups of the recognised ingredients (usual recipe; products differ). Empty is NOT
  /// "allergen free": [uncheckedIngredients] lines were never checked.
  final List<RecipeAllergen> allergens;
  final int uncheckedIngredients;
}

class RecipeAllergen {
  const RecipeAllergen({required this.name, required this.ingredients});

  final String name;
  final List<String> ingredients;
}

class RecipeIngredient {
  const RecipeIngredient({this.name, this.rawText, this.quantity, this.unit});

  /// The catalogue name when matched; null = the line is shown as written.
  final String? name;
  final String? rawText;
  final String? quantity;
  final String? unit;

  String get label => name ?? rawText ?? '';

  /// "500 g", or null when the post gave no amount.
  String? get amount {
    final parts = [
      quantity,
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
