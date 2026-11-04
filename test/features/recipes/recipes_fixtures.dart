import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipes_repository.dart';

const recipeJson = {
  'id': 'r-1',
  'name': 'Nasi Lemak Ayam',
  'sourceUrl': 'https://www.tiktok.com/@makan/video/1',
  'missing': <String>[],
  'createdAt': '2026-11-02 12:00:00',
  'ingredientCount': 2,
  'stepCount': 2,
};

const recipeDetailJson = {
  'id': 'r-1',
  'name': 'Nasi Lemak Ayam',
  'sourceUrl': 'https://www.tiktok.com/@makan/video/1',
  'missing': ['steps'],
  'createdAt': '2026-11-02 12:00:00',
  'ingredients': [
    {'name': 'Ayam', 'rawText': '500g ayam', 'quantity': '500', 'unit': 'g'},
    {
      'name': null,
      'rawText': 'sedikit bahan rahsia',
      'quantity': null,
      'unit': null,
    },
  ],
  'steps': [
    {'stepNo': 1, 'instruction': 'Goreng ayam hingga masak.'},
  ],
};

Recipe recipe({
  String id = 'r-1',
  String name = 'Nasi Lemak Ayam',
  List<String> missing = const [],
  int ingredientCount = 2,
  int stepCount = 2,
}) => Recipe(
  id: id,
  name: name,
  createdAt: DateTime.utc(2026, 11, 3),
  sourceUrl: 'https://www.tiktok.com/@makan/video/1',
  missing: missing,
  ingredientCount: ingredientCount,
  stepCount: stepCount,
);

RecipeDetail recipeDetail({
  List<String> missing = const ['steps'],
  List<RecipeStep> steps = const [
    RecipeStep(stepNo: 1, instruction: 'Goreng ayam hingga masak.'),
  ],
}) => RecipeDetail(
  id: 'r-1',
  name: 'Nasi Lemak Ayam',
  createdAt: DateTime.utc(2026, 11, 2),
  sourceUrl: 'https://www.tiktok.com/@makan/video/1',
  missing: missing,
  ingredients: const [
    RecipeIngredient(
      name: 'Ayam',
      rawText: '500g ayam',
      quantity: '500',
      unit: 'g',
    ),
    RecipeIngredient(rawText: 'sedikit bahan rahsia'),
  ],
  steps: steps,
);

class FakeRecipes implements RecipesRepository {
  List<Recipe> recipes = [];
  RecipeDetail? detailResult;
  Object? error;
  Object? detailError;
  final deleted = <String>[];

  @override
  Future<List<Recipe>> list() async {
    if (error != null) throw error!;
    return recipes;
  }

  @override
  Future<RecipeDetail> get(String id) async {
    if (detailError != null) throw detailError!;
    return detailResult!;
  }

  @override
  Future<void> delete(String id) async {
    if (error != null) throw error!;
    deleted.add(id);
  }
}
