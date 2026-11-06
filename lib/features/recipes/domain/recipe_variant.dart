/// Another web recipe for a catalogue dish (GET /recipes/:id/variants). Its steps stay on its page: only counted.
class RecipeVariant {
  const RecipeVariant({
    required this.id,
    required this.url,
    required this.site,
    required this.match,
    required this.stepCount,
    required this.ingredients,
    this.title,
    this.lang,
    this.adds = const [],
    this.lacks = const [],
  });

  final String id;
  final String url;
  final String? title;
  final String site;

  /// 2-letter code ('ms', 'en'...), null = the page does not say.
  final String? lang;

  /// How sure Clef is that the page is this dish, 0-1.
  final double match;
  final int stepCount;
  final List<VariantIngredient> ingredients;

  /// Catalogue ingredients this variant uses that the dish does not, and the other way round.
  final List<String> adds;
  final List<String> lacks;
}

class VariantIngredient {
  const VariantIngredient({required this.text, this.name, this.confidence});

  final String text;

  /// The catalogue ingredient it is linked to.
  final String? name;

  /// 1 = the catalogue name is in the line; else Clef's certainty; null = no candidate.
  final double? confidence;
}

RecipeVariant recipeVariantFromJson(Map<String, dynamic> j) => RecipeVariant(
  id: j['id'] as String,
  url: j['url'] as String,
  title: j['title'] as String?,
  site: j['site'] as String,
  lang: j['lang'] as String?,
  match: (j['match'] as num).toDouble(),
  stepCount: j['stepCount'] as int? ?? 0,
  ingredients: [
    for (final i
        in (j['ingredients'] as List? ?? const []).cast<Map<String, dynamic>>())
      VariantIngredient(
        text: i['text'] as String,
        name: i['name'] as String?,
        confidence: (i['confidence'] as num?)?.toDouble(),
      ),
  ],
  adds: (j['adds'] as List? ?? const []).cast<String>(),
  lacks: (j['lacks'] as List? ?? const []).cast<String>(),
);
