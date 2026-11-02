import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recipes_fixtures.dart';

void main() {
  test('load keeps the recipes and marks the list loaded', () async {
    final repo = FakeRecipes()..recipes = [recipe(id: 'a'), recipe(id: 'b')];
    final controller = RecipesController(repo);
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.loading, isFalse);
    expect(controller.recipes.map((r) => r.id), ['a', 'b']);
    expect(controller.error, isNull);
  });

  test('a failed load keeps the list and exposes the code', () async {
    final repo = FakeRecipes()
      ..recipes = [recipe(id: 'a')]
      ..error = const ApiException('network');
    final controller = RecipesController(repo);
    await controller.load();
    expect(controller.recipes, isEmpty);
    expect(controller.error, 'network');
    expect(controller.loaded, isTrue);
  });

  test('clear empties the list for the next user', () async {
    final controller = RecipesController(FakeRecipes()..recipes = [recipe()]);
    await controller.load();
    controller.clear();
    expect(controller.recipes, isEmpty);
    expect(controller.loaded, isFalse);
  });

  test('detail passes the repository answer through', () async {
    final controller = RecipesController(
      FakeRecipes()..detailResult = recipeDetail(),
    );
    expect((await controller.detail('r-1')).name, 'Nasi Lemak Ayam');
  });
}
