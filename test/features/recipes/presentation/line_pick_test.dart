import 'package:bukuresipi_flutter/core/widgets/catalogue_photo.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recipes_fixtures.dart';
import 'recipe_editor_test.dart' show editTab, pumpEditor;

const kara = LinePick(
  kind: 'product',
  id: 7,
  name: 'Kara UHT 200ml',
  brand: 'Kara',
  mine: true,
  photo: 'p-kara',
);
const adabi = LinePick(
  kind: 'brand',
  id: 3,
  name: 'Adabi',
  brand: 'Adabi',
  photo: 'p-adabi',
);

RecipeDetail withSantan({LinePick? pick, String? suggested}) => recipeDetail(
  ingredients: [
    RecipeIngredient(
      name: 'Santan',
      rawText: '200 ml santan',
      pick: pick,
      suggested: suggested,
    ),
    const RecipeIngredient(rawText: 'kicap'),
  ],
);

Finder pickChip(int i) => find.byKey(ValueKey('ingredient-pick-$i'));

Future<void> save(WidgetTester t) async {
  await t.tap(find.byTooltip('Save'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets("a row's pick is chosen in the sheet and sent on save", (
    t,
  ) async {
    final fake = await pumpEditor(t, recipe: withSantan());
    fake.pickAnswer = (products: const [kara], brands: const []);
    await editTab(t, 'ingredients');
    expect(find.text('Brand: none'), findsNWidgets(2));
    await t.tap(pickChip(0));
    await t.pumpAndSettle();
    expect(fake.picksAsked.first, ('Santan', null));
    expect(find.text('Your brand'), findsOneWidget);
    expect(find.byType(CataloguePhoto), findsOneWidget); // the product's photo
    await t.tap(find.byKey(const ValueKey('pick-product-7')));
    await t.pumpAndSettle();
    expect(find.text('Kara UHT 200ml'), findsOneWidget);
    await save(t);
    expect(fake.picksSent.single, {0: (kind: 'product', id: 7)});
  });

  testWidgets('a brand is found by name: "Any Adabi"', (t) async {
    final fake = await pumpEditor(t, recipe: withSantan());
    await editTab(t, 'ingredients');
    await t.tap(pickChip(1));
    await t.pumpAndSettle();
    fake.pickAnswer = (products: const [], brands: const [adabi]);
    await t.enterText(find.byKey(const ValueKey('pick-query')), 'ada');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(fake.picksAsked.last, (null, 'ada'));
    expect(find.byType(CataloguePhoto), findsOneWidget); // its logo
    await t.tap(find.text('Any Adabi'));
    await t.pumpAndSettle();
    await save(t);
    expect(fake.picksSent.single, {1: (kind: 'brand', id: 3)});
  });

  testWidgets('a reworded row keeps its pick; × clears it (sent as null)', (
    t,
  ) async {
    final fake = await pumpEditor(t, recipe: withSantan(pick: kara));
    await editTab(t, 'ingredients');
    await t.enterText(find.byKey(const ValueKey('ingredient-amount-0')), '250');
    await save(t);
    expect(fake.edited.single.$3.first, '250 ml santan');
    expect(fake.picksSent.single, {0: (kind: 'product', id: 7)});

    final again = await pumpEditor(t, recipe: withSantan(pick: kara));
    await editTab(t, 'ingredients');
    await t.tap(
      find.descendant(of: pickChip(0), matching: find.byIcon(Icons.cancel)),
    );
    await t.pumpAndSettle();
    expect(find.text('Brand: none'), findsNWidgets(2));
    await save(t);
    expect(again.picksSent.single, {0: null});
  });

  testWidgets(
    'Suggest sends the name and the row shows "Suggested: Kicap Mak Cik"',
    (t) async {
      final fake = await pumpEditor(t, recipe: withSantan());
      await editTab(t, 'ingredients');
      await t.tap(pickChip(1));
      await t.pumpAndSettle();
      await t.tap(find.text('Not listed? Suggest it'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('pick-suggest-name')),
        'Kicap Mak Cik',
      );
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();
      expect(fake.suggestions.single, ('r-1', 'kicap', 'Kicap Mak Cik'));
      expect(find.text('Suggested: Kicap Mak Cik'), findsOneWidget);
    },
  );

  testWidgets('a failed product load shows in the list, not under Suggest', (
    t,
  ) async {
    final fake = await pumpEditor(t, recipe: withSantan());
    fake.picksError = const ApiException('server_error', status: 500);
    await editTab(t, 'ingredients');
    await t.tap(pickChip(0));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-load-error')), findsOneWidget);
    await t.tap(find.text('Not listed? Suggest it'));
    await t.pumpAndSettle();
    final field = t.widget<TextField>(
      find.byKey(const ValueKey('pick-suggest-name')),
    );
    expect(field.decoration!.errorText, isNull);
  });

  testWidgets('a reworded line says to save first instead of Suggest', (
    t,
  ) async {
    await pumpEditor(t, recipe: withSantan());
    await editTab(t, 'ingredients');
    await t.enterText(
      find.byKey(const ValueKey('ingredient-name-1')),
      'kicap manis',
    );
    await t.tap(pickChip(1));
    await t.pumpAndSettle();
    expect(find.text('Not listed? Suggest it'), findsNothing);
    expect(
      find.text('Save the recipe first to suggest a brand that is not listed.'),
      findsOneWidget,
    );
  });
}
