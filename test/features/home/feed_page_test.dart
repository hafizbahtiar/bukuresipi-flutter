import 'package:bukuresipi_flutter/features/home/presentation/feed_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../places/places_fixtures.dart';
import '../recipes/recipes_fixtures.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late FakePlaces places;

  Future<void> pump(WidgetTester t, {bool located = true}) async {
    t.view.physicalSize = const Size(
      2400,
      6000,
    ); // every section on screen (a ListView builds only what shows)
    addTearDown(t.view.reset);
    places = FakePlaces()
      ..nearbyResults = [
        nearbyBranch(branchId: 'b-1', name: 'Kedai Sederhana', distanceM: 900),
        nearbyBranch(branchId: 'b-2', name: 'Warung Pak Ali', distanceM: 300),
      ];
    final recipes = FakeRecipes()
      ..communityList = [recipe(id: 'c-1', name: 'Kek Batik Viral')]
      ..dishList = const [
        Dish(
          id: 'd-1',
          name: 'Rendang Daging',
          category: 'Lauk',
          ingredientCount: 9,
        ),
      ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => FeedPage(
            locate: () async => located ? (lat: 3.15, lng: 101.7) : null,
          ),
        ),
        GoRoute(path: '/map', builder: (_, _) => const Text('the map')),
      ],
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PlacesController(places)),
          ChangeNotifierProvider(create: (_) => RecipesController(recipes)),
        ],
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
  }

  testWidgets(
    'Home shows restaurants near the phone (nearest first), community recipes and dishes',
    (t) async {
      await pump(t);
      expect(places.nearbyCalls.single, (3.15, 101.7, 5.0));
      expect(find.text(l.feedNearYou), findsOneWidget);
      final near = t.getTopLeft(find.text('Warung Pak Ali')).dy;
      expect(near, lessThan(t.getTopLeft(find.text('Kedai Sederhana')).dy));
      expect(find.text('Kek Batik Viral'), findsOneWidget);
      expect(find.text('Rendang Daging'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('feed-kind-recipes')));
      await t.pumpAndSettle();
      expect(find.text('Warung Pak Ali'), findsNothing);
      expect(
        find.byKey(const ValueKey('feed-halal')),
        findsNothing,
      ); // restaurant filters only with restaurants
      expect(find.text('Kek Batik Viral'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('feed-kind-restaurants')));
      await t.pumpAndSettle();
      expect(find.text('Kek Batik Viral'), findsNothing);
      expect(find.text('Warung Pak Ali'), findsOneWidget);
    },
  );

  testWidgets(
    'one search box: restaurants on the phone, recipes on the server',
    (t) async {
      await pump(t);
      await t.enterText(find.byType(TextField), 'warung');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(find.text('Warung Pak Ali'), findsOneWidget);
      expect(find.text('Kedai Sederhana'), findsNothing);
      expect(find.text('Kek Batik Viral'), findsNothing);
      expect(find.text(l.recipesEmptyCommunity), findsOneWidget);
    },
  );

  testWidgets(
    'location refused: Home says how to see nearby restaurants; recipes still show',
    (t) async {
      await pump(t, located: false);
      expect(places.nearbyCalls, isEmpty);
      expect(find.text(l.feedLocationOff), findsOneWidget);
      expect(find.text('Kek Batik Viral'), findsOneWidget);
    },
  );

  testWidgets('the map button opens the map', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('feed-map')));
    await t.pumpAndSettle();
    expect(find.text('the map'), findsOneWidget);
  });
}
