import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../shopping/shopping_fixtures.dart';
import '../recipes_fixtures.dart';
import 'recipe_pages_test.dart' show app;

const _lines = [
  RecipeIngredient(name: 'Beras putih', rawText: '2 cawan beras putih'),
  RecipeIngredient(
    name: 'Kacang tanah',
    rawText: 'kacang tanah (jika suka)',
    optional: true,
  ),
];

void main() {
  late FakeRecipes repo;
  late FakeShopping shop;

  Future<void> pump(WidgetTester t, RecipeDetail detail) async {
    repo = FakeRecipes()..detailResult = detail;
    shop = FakeShopping();
    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: RecipesController(repo)),
          ChangeNotifierProvider.value(value: ShoppingController(shop)),
        ],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'an optional line is tagged; its allergen is still listed, as "only if you add it"',
    (t) async {
      await pump(
        t,
        recipeDetail(
          ingredients: _lines,
          allergens: const [
            RecipeAllergen(
              name: 'Kacang tanah',
              ingredients: ['Kacang tanah'],
              optionalOnly: true,
            ),
          ],
        ),
      );
      expect(find.text('Optional'), findsOneWidget);
      // The allergens are their own section (a tab here).
      await t.tap(find.byKey(const ValueKey('recipe-tab-others')));
      await t.pumpAndSettle();
      expect(find.textContaining('only if you add it'), findsOneWidget);
    },
  );

  testWidgets('the line sheet flips the optional mark', (t) async {
    await pump(t, recipeDetail(ingredients: _lines));
    await t.tap(find.textContaining('Beras putih'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('ingredient-optional')));
    await t.pumpAndSettle();
    expect(repo.optionalSet, [('r-1', 0, true)]);
    expect(repo.linked, isEmpty); // the link is left alone
  });

  testWidgets('Add to list asks about optional lines; closing adds nothing', (
    t,
  ) async {
    await pump(t, recipeDetail(ingredients: _lines));
    Future<void> add() async {
      await t.tap(find.byKey(const ValueKey('more-menu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Add to list'));
      await t.pumpAndSettle();
    }

    await add();
    expect(find.textContaining('1 optional ingredient.'), findsOneWidget);
    await t.tap(find.text("Only what's needed"));
    await t.pumpAndSettle();
    expect(shop.skippedOptional, [true]);

    await add();
    await t.tap(find.text('Everything, optional too'));
    await t.pumpAndSettle();
    expect(shop.skippedOptional, [true, false]);

    await add();
    await t.tapAt(const Offset(5, 5)); // outside the sheet
    await t.pumpAndSettle();
    expect(shop.skippedOptional, [true, false]);
  });

  testWidgets('no optional lines: nothing is asked', (t) async {
    await pump(t, recipeDetail());
    await t.tap(find.byKey(const ValueKey('more-menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to list'));
    await t.pumpAndSettle();
    expect(shop.skippedOptional, [false]);
  });
}
