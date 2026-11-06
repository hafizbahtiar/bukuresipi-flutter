import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipes_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../recipes_fixtures.dart';

void main() {
  testWidgets(
    'the Recipes tab searches mine on the phone and the catalogue on the server',
    (t) async {
      final repo = FakeRecipes()
        ..recipes = [
          recipe(id: 'r-1', name: 'Nasi Lemak Ayam'),
          recipe(id: 'r-2', name: 'Kuih Lapis'),
        ]
        ..dishList = const [
          Dish(
            id: 'd-1',
            name: 'Rendang Daging',
            category: 'Lauk',
            ingredientCount: 9,
          ),
        ];
      final recipes = RecipesController(repo);
      await recipes.load();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: recipes,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ms')],
            home: RecipesPage(),
          ),
        ),
      );
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text('Kuih Lapis'), findsOneWidget);
      expect(
        find.text(l.recipesFamily),
        findsNothing,
      ); // no family, no Family shelf
      await t.enterText(find.byType(TextField), 'nasi');
      await t.pump(const Duration(milliseconds: 350));
      expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
      expect(find.text('Kuih Lapis'), findsNothing);
      await t.enterText(find.byType(TextField), 'rendang');
      await t.pump(const Duration(milliseconds: 350));
      await t.tap(find.text(l.recipesCatalogue));
      await t.pumpAndSettle();
      expect(find.text('Rendang Daging'), findsOneWidget);
    },
  );

  testWidgets(
    'Write your own recipe: the empty editor, then the saved recipe opens',
    (t) async {
      final repo = FakeRecipes()..detailResult = recipeDetail();
      final recipes = RecipesController(repo);
      await recipes.load();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const RecipesPage()),
          GoRoute(
            path: '/recipes/:id',
            builder: (_, s) => Text('opened ${s.pathParameters['id']}'),
          ),
        ],
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: recipes,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ms')],
          ),
        ),
      );
      await t.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));

      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      expect(find.text(l.recipeNew), findsOneWidget);
      await t.tap(find.text(l.save));
      await t.pump();
      expect(
        find.text(l.recipeEditNameRequired),
        findsOneWidget,
      ); // no name, nothing sent
      expect(repo.created, isEmpty);

      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Kuih Nenek');
      await t.enterText(
        fields.at(1),
        '2 cawan tepung\n1 biji telur',
      ); // a pasted list splits into rows
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Kukus 20 minit.');
      await t.tap(find.text(l.save));
      await t.pumpAndSettle();

      final (name, ingredients, steps) = repo.created.single;
      expect(name, 'Kuih Nenek');
      expect(ingredients, ['2 cawan tepung', '1 biji telur']);
      expect(steps, ['Kukus 20 minit.']);
      expect(find.text('opened r-1'), findsOneWidget);
    },
  );
}
