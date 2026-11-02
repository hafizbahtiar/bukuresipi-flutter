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
  testWidgets('the book lists recipes under the places', (t) async {
    final places = PlacesController(FakePlaces());
    final recipes = RecipesController(FakeRecipes()..recipes = [recipe()]);
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

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
    expect(find.text('2 ingredients · 2 steps'), findsOneWidget);
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
