/// A recipe the user shared into Bukuresipi.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sourceUrl,
    this.missing = const [],
    this.ingredientCount = 0,
    this.stepCount = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// The post it came from; opens the video.
  final String? sourceUrl;

  /// 'name' | 'ingredients' | 'steps': what the post did not give.
  final List<String> missing;
  final int ingredientCount;
  final int stepCount;
}

class RecipeDetail {
  const RecipeDetail({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sourceUrl,
    this.shareId,
    this.missing = const [],
    required this.ingredients,
    required this.steps,
    this.allergens = const [],
    this.uncheckedIngredients = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String? sourceUrl;

  /// The share it was imported from: its screenshot or post thumbnail (ShareRepository.image).
  final String? shareId;
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
