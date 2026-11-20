import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/pantry_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shopping/shopping_fixtures.dart';
import '../recipes_fixtures.dart';

void main() {
  testWidgets(
    'ingredients are added and kept on the phone; results show cook now, missing and add-missing',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'pantry.ingredients': ['Telur'],
      });
      final recipes = FakeRecipes()
        ..pantryAnswer = [
          (
            recipe: Recipe(
              id: 'r-1',
              name: 'Telur Dadar',
              createdAt: DateTime(2026),
            ),
            have: 3,
            required: 3,
            missing: const [],
            unknown: const [],
          ),
          (
            recipe: Recipe(
              id: 'r-2',
              name: 'Telur Kicap',
              createdAt: DateTime(2026),
            ),
            have: 1,
            required: 2,
            missing: const ['Kicap'],
            unknown: const ['daun pandan'],
          ),
        ];
      final shoppingRepo = FakeShopping();
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RecipesController(recipes)),
            ChangeNotifierProvider(
              create: (_) => ShoppingController(shoppingRepo),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PantryPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Telur'), findsOneWidget); // remembered
      await t.enterText(
        find.byKey(const ValueKey('pantry-field')),
        'Bawang merah',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'pantry.ingredients',
        ),
        ['Telur', 'Bawang merah'],
      );

      await t.tap(find.text('Salt, sugar and cooking oil are in my kitchen'));
      await t.tap(find.byKey(const ValueKey('pantry-find')));
      await t.pumpAndSettle();
      final (asked, staples) = recipes.pantryAsked.single;
      expect(asked, ['Telur', 'Bawang merah']);
      expect(staples, isFalse);
      expect(find.text('Cook now'), findsOneWidget);
      expect(find.text('Missing: Kicap'), findsOneWidget);
      expect(find.text('Check: daun pandan'), findsOneWidget);
      await t.tap(find.byTooltip('Add missing to shopping list'));
      await t.pumpAndSettle();
      expect(find.text('Added to your shopping list'), findsOneWidget);
      expect(shoppingRepo.items.map((i) => i.text), ['Kicap']);
    },
  );

  testWidgets(
    'nothing fits: Suggest a dish lists AI names with the ingredients they use; again after a new search; the limit is said',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'pantry.ingredients': ['Telur', 'Kicap'],
      });
      final recipes = FakeRecipes()
        ..dishAnswer = [
          (name: 'Telur Masak Kicap', uses: const ['Telur', 'Kicap']),
        ];
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RecipesController(recipes)),
            ChangeNotifierProvider(
              create: (_) => ShoppingController(FakeShopping()),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PantryPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pantry-suggest')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pantry-find')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pantry-suggest')));
      await t.pumpAndSettle();
      expect(recipes.dishesAsked, [
        ['Telur', 'Kicap'],
      ]);
      expect(
        find.byKey(const ValueKey('pantry-dish-Telur Masak Kicap')),
        findsOneWidget,
      );
      expect(find.text('Uses: Telur, Kicap'), findsOneWidget);
      expect(find.byKey(const ValueKey('pantry-suggest')), findsNothing);

      // A new search clears the old suggestions; none this time is said, a refusal is shown.
      await t.tap(find.byKey(const ValueKey('pantry-find')));
      await t.pumpAndSettle();
      expect(find.text('Uses: Telur, Kicap'), findsNothing);
      recipes.dishAnswer = const [];
      await t.tap(find.byKey(const ValueKey('pantry-suggest')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'No dish comes to mind with these. Add a few more ingredients.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('pantry-find')));
      await t.pumpAndSettle();
      recipes.dishError = const ApiException('suggest_limit', status: 429);
      await t.tap(find.byKey(const ValueKey('pantry-suggest')));
      await t.pumpAndSettle();
      expect(
        find.text("That's 10 dish suggestions today. Try again tomorrow."),
        findsOneWidget,
      );
    },
  );
}
