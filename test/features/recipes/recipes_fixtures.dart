import 'dart:async';

import 'dart:typed_data';

import 'package:bukuresipi_flutter/features/recipes/domain/recipe_variant.dart';
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
  List<RecipeAllergen> allergens = const [],
  List<RecipeIngredient>? ingredients,
  bool canEdit = true,
  RecipeVisibility visibility = RecipeVisibility.private,
  RecipeOwner? owner,
  RecipeSourceType sourceType = RecipeSourceType.link,
  String sourceUrl = 'https://www.tiktok.com/@makan/video/1',
  String? cover,
  String id = 'r-1',
  String name = 'Nasi Lemak Ayam',
}) => RecipeDetail(
  cover: cover,
  sourceType: sourceType,
  canEdit: canEdit,
  visibility: visibility,
  owner: owner,
  id: id,
  name: name,
  createdAt: DateTime.utc(2026, 11, 2),
  sourceUrl: sourceUrl,
  missing: missing,
  ingredients:
      ingredients ??
      const [
        RecipeIngredient(
          name: 'Ayam',
          rawText: '500g ayam',
          quantity: '500',
          unit: 'g',
        ),
        RecipeIngredient(rawText: 'sedikit bahan rahsia'),
      ],
  steps: steps,
  allergens: allergens,
  uncheckedIngredients: 1,
);

class FakeRecipes implements RecipesRepository {
  final covers = <(String, String)>[];
  final coversRemoved = <String>[];

  @override
  Future<RecipeDetail> setCover(String id, String path) async {
    covers.add((id, path));
    return detailResult!;
  }

  @override
  Future<void> removeCover(String id) async => coversRemoved.add(id);

  @override
  Future<Uint8List?> cover(String id, String cover) async => null;

  List<Recipe> recipes = [];
  RecipeDetail? detailResult;
  List<RecipeVariant> variantList = const [];

  @override
  Future<List<RecipeVariant>> variants(String id) async => variantList;
  Object? error;
  Object? detailError;
  final deleted = <String>[];

  List<Recipe> family = [];
  List<Recipe> communityList = [];

  /// While set and not completed, community / dishes answers wait for it (a slow network).
  Completer<void>? communityGate;
  Completer<void>? dishesGate;
  List<Dish> dishList = [];
  final copied = <String>[];
  final visibilities = <(String, RecipeVisibility)>[];
  final reports = <(String, String)>[];

  @override
  Future<List<Recipe>> list({bool family = false}) async {
    if (error != null) throw error!;
    return family ? this.family : recipes;
  }

  @override
  Future<({List<Recipe> recipes, String? next})> community({
    String? query,
    String? cursor,
    int? limit,
  }) async {
    await communityGate?.future;
    return (
      recipes: communityList
          .where(
            (r) =>
                query == null ||
                r.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList(),
      next: null,
    );
  }

  @override
  Future<({List<Dish> dishes, String? next})> dishes({
    String? query,
    String? cursor,
    int? limit,
  }) async {
    await dishesGate?.future;
    return (
      dishes: dishList
          .where(
            (d) =>
                query == null ||
                d.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList(),
      next: null,
    );
  }

  @override
  Future<RecipeDetail> copy(String id) async {
    copied.add(id);
    return detailResult!;
  }

  @override
  Future<RecipeDetail> setVisibility(
    String id,
    RecipeVisibility visibility,
  ) async {
    if (error != null) throw error!;
    visibilities.add((id, visibility));
    return detailResult!;
  }

  @override
  Future<void> report(String id, String reason, {String? note}) async =>
      reports.add((id, reason));

  /// While set and not completed, the recipe detail waits for it (the page still loading).
  Completer<void>? detailGate;

  @override
  Future<RecipeDetail> get(String id) async {
    await detailGate?.future;
    if (detailError != null) throw detailError!;
    return detailResult!;
  }

  @override
  Future<void> delete(String id) async {
    if (error != null) throw error!;
    deleted.add(id);
  }

  List<String> ingredientNames = const ['Susu segar', 'Susu pekat'];
  final linked = <(String, int, String?)>[];

  @override
  Future<List<String>> searchIngredients(String query) async => ingredientNames;

  @override
  Future<RecipeDetail> linkIngredient(
    String id,
    int index,
    String? name,
  ) async {
    linked.add((id, index, name));
    return detailResult!;
  }

  final optionalSet = <(String, int, bool)>[];
  @override
  Future<RecipeDetail> setIngredientOptional(
    String id,
    int index,
    bool optional,
  ) async {
    optionalSet.add((id, index, optional));
    return detailResult!;
  }

  final edited = <(String, String, List<String>, List<String>)>[];

  final created = <(String, List<String>, List<String>)>[];

  @override
  Future<RecipeDetail> create({
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) async {
    created.add((name, ingredients, steps));
    return detailResult!;
  }

  @override
  Future<RecipeDetail> edit(
    String id, {
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) async {
    edited.add((id, name, ingredients, steps));
    return detailResult!;
  }
}
