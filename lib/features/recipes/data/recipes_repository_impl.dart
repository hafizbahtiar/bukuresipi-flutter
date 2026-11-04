import 'package:dio/dio.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/db_time.dart';
import '../domain/recipe.dart';
import '../domain/recipes_repository.dart';

class RecipesRepositoryImpl implements RecipesRepository {
  RecipesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Recipe>> list() => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/recipes')).data!;
    final rows = data['recipes'] as List;
    final recipes = <Recipe>[];
    for (final j in rows) {
      try {
        recipes.add(recipeFromJson(j as Map<String, dynamic>));
      } catch (e) {
        log('recipes: skipped row: $e; row=${logJson(j)}');
      }
    }
    log('recipes: ${recipes.length}/${rows.length} rows loaded');
    return recipes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<RecipeDetail> get(String id) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/recipes/$id')).data!;
    return recipeDetailFromJson(data);
  });

  @override
  Future<void> delete(String id) =>
      apiCall(() => _dio.delete<void>('/recipes/$id'));
}

List<String> _missing(Object? v) => [
  ...((v as List?) ?? const []).cast<String>(),
];

Recipe recipeFromJson(Map<String, dynamic> j) => Recipe(
  id: j['id'] as String,
  name: j['name'] as String,
  createdAt: dbTime(j['createdAt'] as String),
  sourceUrl: j['sourceUrl'] as String?,
  missing: _missing(j['missing']),
  ingredientCount: (j['ingredientCount'] as num?)?.toInt() ?? 0,
  stepCount: (j['stepCount'] as num?)?.toInt() ?? 0,
);

RecipeDetail recipeDetailFromJson(Map<String, dynamic> j) => RecipeDetail(
  id: j['id'] as String,
  name: j['name'] as String,
  createdAt: dbTime(j['createdAt'] as String),
  sourceUrl: j['sourceUrl'] as String?,
  shareId: j['shareId'] as String?,
  missing: _missing(j['missing']),
  ingredients: [
    for (final i
        in (j['ingredients'] as List? ?? const []).cast<Map<String, dynamic>>())
      RecipeIngredient(
        name: i['name'] as String?,
        rawText: i['rawText'] as String?,
        quantity: i['quantity'] as String?,
        unit: i['unit'] as String?,
      ),
  ],
  steps: [
    for (final s
        in (j['steps'] as List? ?? const []).cast<Map<String, dynamic>>())
      RecipeStep(
        stepNo: (s['stepNo'] as num).toInt(),
        instruction: s['instruction'] as String,
      ),
  ],
);
