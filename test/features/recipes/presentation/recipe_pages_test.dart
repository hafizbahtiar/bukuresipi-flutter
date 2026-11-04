import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../places/places_fixtures.dart';
import '../../shares/presentation/share_intake_test.dart' show FakeShares;
import '../recipes_fixtures.dart';

Widget app({
  required List<SingleChildWidget> providers,
  required Widget home,
}) => MultiProvider(
  providers: providers,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ms')],
    home: home,
  ),
);

void main() {
  testWidgets('the book lists places and recipes together, newest first', (
    t,
  ) async {
    // Place from 2026-11-02 (fixture), recipe from the day after: the recipe comes first.
    final places = PlacesController(FakePlaces()..places = [place(id: 'p')]);
    final recipes = RecipesController(
      FakeRecipes()
        ..recipes = [
          recipe(),
          recipe(id: 'r-2', name: 'Ayam Rebus Pedas', stepCount: 0),
        ],
    );
    final recent = RecentShares(FakeShares(), onFinished: () async {});
    await places.load();
    await recipes.load();

    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: recipes),
          ChangeNotifierProvider.value(value: recent),
        ],
        home: const PlacesListPage(),
      ),
    );
    await t.pump();

    expect(find.text('Recipes'), findsNothing, reason: 'no separate section');
    expect(find.byIcon(Icons.storefront), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsNWidgets(2));
    expect(find.text('2 ingredients · 2 steps'), findsOneWidget);
    expect(find.text('2 ingredients'), findsOneWidget, reason: 'no "0 steps"');
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    expect(y('Nasi Lemak Ayam'), lessThan(y('Nasi Kandar Pelita')));
  });

  testWidgets('the recipe page shows its ingredients, steps and missing note', (
    t,
  ) async {
    final recipes = RecipesController(
      FakeRecipes()..detailResult = recipeDetail(),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
    expect(find.textContaining('Not everything was found'), findsOneWidget);
    expect(find.textContaining('500 g'), findsOneWidget);
    expect(find.textContaining('sedikit bahan rahsia'), findsOneWidget);
    expect(find.text('Goreng ayam hingga masak.'), findsOneWidget);
    expect(find.text('Open video'), findsOneWidget);
  });

  testWidgets('a recipe with no steps shows no Steps heading', (t) async {
    final recipes = RecipesController(
      FakeRecipes()..detailResult = recipeDetail(steps: const []),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Steps'), findsNothing);
  });

  testWidgets('a recipe is removed only after confirming', (t) async {
    final fake = FakeRecipes()
      ..recipes = [recipe()]
      ..detailResult = recipeDetail();
    final recipes = RecipesController(fake);
    await recipes.load();
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Remove from my book'));
    await t.pumpAndSettle();
    expect(fake.deleted, isEmpty);
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await t.pumpAndSettle();
    expect(fake.deleted, ['r-1']);
    expect(recipes.recipes, isEmpty);
  });

  testWidgets('a recipe load error shows a notice while places still list', (
    t,
  ) async {
    final places = PlacesController(FakePlaces()..places = [place(id: 'p')]);
    final fake = FakeRecipes()..error = const ApiException('network');
    final recipes = RecipesController(fake);
    final recent = RecentShares(FakeShares(), onFinished: () async {});
    await places.load();
    await recipes.load();

    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: recipes),
          ChangeNotifierProvider.value(value: recent),
        ],
        home: const PlacesListPage(),
      ),
    );
    await t.pump();

    expect(find.text('Nasi Kandar Pelita'), findsOneWidget);
    expect(find.text('Could not load your recipes.'), findsOneWidget);

    fake
      ..error = null
      ..recipes = [recipe()];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Could not load your recipes.'), findsNothing);
    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
  });

  testWidgets('a recipe that is gone says so', (t) async {
    final recipes = RecipesController(
      FakeRecipes()..detailError = const ApiException('not_found', status: 404),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.textContaining('no longer in your book'), findsOneWidget);
  });
}
