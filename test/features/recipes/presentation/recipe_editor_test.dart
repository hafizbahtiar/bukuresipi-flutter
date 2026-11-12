import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_edit_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../recipes_fixtures.dart';

/// The editor behind an "open" button, so leaving it (back) can be tested.
Future<FakeRecipes> pumpEditor(WidgetTester t, {RecipeDetail? recipe}) async {
  final fake = FakeRecipes()..detailResult = recipeDetail();
  await t.pumpWidget(
    ChangeNotifierProvider.value(
      value: RecipesController(fake),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecipeEditPage(recipe: recipe),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return fake;
}

/// The editor's tabs: Details | Ingredients | Steps.
Future<void> editTab(WidgetTester t, String name) async {
  await t.tap(find.byKey(ValueKey('recipe-edit-tab-$name')));
  await t.pumpAndSettle();
}

Finder nameField(int i) => find.byKey(ValueKey('ingredient-name-$i'));
Finder amountField(int i) => find.byKey(ValueKey('ingredient-amount-$i'));
bool focused(WidgetTester t, Finder field) =>
    t.widget<TextField>(field).focusNode!.hasFocus;

void main() {
  test('splitLine reads a line as the server does; joinLine puts it back', () {
    expect(splitLine('1 1/2 cawan tepung gandum'), (
      amount: '1 1/2',
      unit: 'cawan',
      name: 'tepung gandum',
    ));
    expect(splitLine('2 sudu besar gula'), (
      amount: '2',
      unit: 'sudu besar',
      name: 'gula',
    ));
    expect(splitLine('2 sb gula'), (amount: '2', unit: 'sb', name: 'gula'));
    expect(splitLine('3 biji telur'), (
      amount: '3',
      unit: 'biji',
      name: 'telur',
    ));
    expect(splitLine('2 bawang merah'), (
      amount: '2',
      unit: null,
      name: 'bawang merah',
    ));
    expect(splitLine('garam secukupnya'), (
      amount: '',
      unit: null,
      name: 'garam secukupnya',
    ));
    expect(splitLine('500g ayam'), (amount: '', unit: null, name: '500g ayam'));
    expect(joinLine('1/2', 'cawan', ' santan '), '1/2 cawan santan');
    expect(joinLine('', null, 'garam'), 'garam');
  });

  testWidgets(
    'Enter on an ingredient starts the next row and puts the cursor in it',
    (t) async {
      await pumpEditor(t);
      await editTab(t, 'ingredients');
      await t.enterText(nameField(0), 'gula');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(nameField(1), findsOneWidget);
      expect(focused(t, nameField(1)), isTrue);
      // Enter on that empty last row does not pile up more empty rows.
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(nameField(2), findsNothing);
      // Enter in an amount goes on to the next row too.
      await t.enterText(nameField(1), 'telur');
      await t.enterText(amountField(0), '2');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(focused(t, nameField(1)), isTrue);
    },
  );

  testWidgets(
    'amount, unit and ingredient are saved as one line; a step Enter moves on',
    (t) async {
      final fake = await pumpEditor(t);
      await t.enterText(find.widgetWithText(TextField, 'Name'), 'Kek Pisang');
      await editTab(t, 'ingredients');
      await t.enterText(nameField(0), 'tepung gandum');
      await t.enterText(amountField(0), '1 1/2');
      await t.tap(find.byKey(const ValueKey('ingredient-unit-0')));
      await t.pumpAndSettle();
      await t.tap(find.text('cawan').last);
      await t.pumpAndSettle();
      await editTab(t, 'steps');
      await t.enterText(find.byKey(const ValueKey('step-0')), 'Pukul telur.');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();
      expect(focused(t, find.byKey(const ValueKey('step-1'))), isTrue);
      await t.enterText(
        find.byKey(const ValueKey('step-1')),
        'Bakar 40 minit.',
      );
      await t.tap(find.byTooltip('Save'));
      await t.pumpAndSettle();
      final (name, ingredients, steps) = fake.created.single;
      expect(name, 'Kek Pisang');
      expect(ingredients, ['1 1/2 cawan tepung gandum']);
      expect(steps, ['Pukul telur.', 'Bakar 40 minit.']);
    },
  );

  testWidgets(
    'an amount with no ingredient is flagged, its tab shown, and nothing is saved',
    (t) async {
      final fake = await pumpEditor(t);
      await t.enterText(find.widgetWithText(TextField, 'Name'), 'Kek');
      await editTab(t, 'ingredients');
      await t.enterText(amountField(0), '2');
      // Saved from another tab: the editor goes to the row with the problem.
      await editTab(t, 'details');
      await t.tap(find.byTooltip('Save'));
      await t.pumpAndSettle();
      expect(
        find.text('Write the ingredient for this amount.'),
        findsOneWidget,
      );
      expect(fake.created, isEmpty);
      expect(focused(t, nameField(0)), isTrue);
    },
  );

  testWidgets('a missing name on Save brings back the Details tab', (t) async {
    await pumpEditor(t);
    await editTab(t, 'steps');
    await t.tap(find.byTooltip('Save'));
    await t.pumpAndSettle();
    expect(find.text('Give the recipe a name.'), findsOneWidget);
  });

  testWidgets(
    'a stored line left alone is sent word for word (it keeps its link); a changed one is rebuilt',
    (t) async {
      final fake = await pumpEditor(
        t,
        recipe: recipeDetail(
          ingredients: const [
            RecipeIngredient(
              name: 'Gula',
              rawText: '2 sb  gula',
              quantity: '2',
              unit: 'sb',
            ),
            RecipeIngredient(rawText: '1 cawan santan'),
          ],
        ),
      );
      await editTab(t, 'ingredients');
      expect(t.widget<TextField>(amountField(0)).controller!.text, '2');
      expect(
        find.text('sb'),
        findsOneWidget,
      ); // the stored spelling stays selectable
      await t.enterText(amountField(1), '2');
      await t.tap(find.byTooltip('Save'));
      await t.pumpAndSettle();
      expect(fake.edited.single.$3, ['2 sb  gula', '2 cawan santan']);
    },
  );

  testWidgets(
    'leaving with changes asks first; without changes it just closes',
    (t) async {
      await pumpEditor(t);
      await editTab(t, 'ingredients');
      await t.enterText(nameField(0), 'gula');
      await t.pump(); // the frame that rebuilds the page with its change
      await t.binding.handlePopRoute(); // Android back: respects PopScope (pageBack() does not)
      await t.pumpAndSettle();
      expect(find.text('Discard your changes to this recipe?'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute(); // Android back: respects PopScope (pageBack() does not)
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('removing the stored cover is sent after the recipe saves', (
    t,
  ) async {
    final fake = await pumpEditor(t, recipe: recipeDetail(cover: 'c-1'));
    expect(find.text('Change photo'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cover-remove')));
    await t.pump();
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-remove')), findsNothing);
    await t.tap(find.byTooltip('Save'));
    await t.pumpAndSettle();
    expect(fake.edited, hasLength(1));
    expect(fake.coversRemoved, ['r-1']);
    expect(fake.covers, isEmpty);
  });

  testWidgets('a new recipe offers a photo and saves without one', (t) async {
    final fake = await pumpEditor(t);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-remove')), findsNothing);
    await t.enterText(find.byType(TextField).first, 'Kek Batik');
    await t.tap(find.byTooltip('Save'));
    await t.pumpAndSettle();
    expect(fake.created, hasLength(1));
    expect(fake.covers, isEmpty);
    expect(fake.coversRemoved, isEmpty);
  });
}
