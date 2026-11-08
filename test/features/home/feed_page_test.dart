import 'package:bukuresipi_flutter/features/home/presentation/feed_page.dart';
import 'package:bukuresipi_flutter/features/home/presentation/widgets/feed_card.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
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

  Future<void> pump(
    WidgetTester t, {
    bool located = true,
    int community = 1,
    RatingSummary? rating,
  }) async {
    t.view.physicalSize = const Size(
      2400,
      6000,
    ); // every section on screen (a ListView builds only what shows)
    addTearDown(t.view.reset);
    places = FakePlaces()
      ..nearbyResults = [
        nearbyBranch(branchId: 'b-1', name: 'Kedai Sederhana', distanceM: 900),
        nearbyBranch(
          branchId: 'b-2',
          name: 'Warung Pak Ali',
          distanceM: 300,
          rating: rating,
        ),
      ];
    final recipes = FakeRecipes()
      ..communityList = [
        recipe(id: 'c-1', name: 'Kek Batik Viral'),
        for (var i = 2; i <= community; i++)
          recipe(id: 'c-$i', name: 'Resipi $i'),
      ]
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
        GoRoute(
          path: '/recipes/:id',
          builder: (_, st) => Text('recipe ${st.pathParameters['id']}'),
        ),
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

  List<String> cardKeys(WidgetTester t) => [
    for (final e in find.byType(FeedCard).evaluate())
      (e.widget.key! as ValueKey<String>).value,
  ];

  testWidgets(
    'one grid: community recipes, then dishes; every 4th card a nearby restaurant (nearest first) tagged Near me',
    (t) async {
      await pump(t, community: 3);
      expect(places.nearbyCalls.single, (3.15, 101.7, 5.0));
      expect(cardKeys(t), [
        'feed-recipe-c-1',
        'feed-recipe-c-2',
        'feed-recipe-c-3',
        'feed-place-b-2', // 300 m
        'feed-dish-d-1',
        'feed-place-b-1', // 900 m: after the last recipe
      ]);
      expect(find.text('${l.feedNearMe} · 300 m'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('feed-kind-recipes')));
      await t.pumpAndSettle();
      expect(find.text('Warung Pak Ali'), findsNothing);
      expect(
        find.byKey(const ValueKey('feed-halal')),
        findsNothing,
      ); // restaurant filters only with restaurants

      await t.tap(find.byKey(const ValueKey('feed-kind-restaurants')));
      await t.pumpAndSettle();
      expect(cardKeys(t), ['feed-place-b-2', 'feed-place-b-1']);
    },
  );

  testWidgets(
    'a restaurant card says what it is and its key facts: stars only when rated, the halal claim as a claim',
    (t) async {
      await pump(t);
      Finder inCard(String key, Finder f) =>
          find.descendant(of: find.byKey(ValueKey(key)), matching: f);
      expect(
        inCard('feed-place-b-2', find.text(l.feedKindRestaurant.toUpperCase())),
        findsOneWidget,
      );
      expect(inCard('feed-place-b-2', find.text('Melayu')), findsOneWidget);
      expect(
        inCard('feed-place-b-2', find.text(l.feedSaysHalal)),
        findsOneWidget,
      );
      expect(
        inCard('feed-place-b-2', find.byIcon(Icons.star_rounded)),
        findsNothing,
      ); // no ratings yet
      expect(
        inCard('feed-dish-d-1', find.text(l.feedKindDish.toUpperCase())),
        findsOneWidget,
      );
      expect(
        inCard('feed-dish-d-1', find.text(l.recipeIngredientCount(9))),
        findsOneWidget,
      );
      // No photo: the cooking drawing, not a bare icon.
      expect(
        inCard(
          'feed-dish-d-1',
          find.byKey(const ValueKey('feed-card-drawing')),
        ),
        findsOneWidget,
      );
      expect(
        inCard(
          'feed-place-b-2',
          find.byKey(const ValueKey('feed-card-drawing')),
        ),
        findsNothing,
      ); // places keep their shop icon
    },
  );

  testWidgets('a rated restaurant shows its stars and count', (t) async {
    await pump(t, rating: const RatingSummary(average: 4.56, count: 12));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('feed-place-b-2')),
        matching: find.text('4.6 (12)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'search suggests as you type (restaurants, recipes, "Search ..."); submitting filters the grid',
    (t) async {
      await pump(t);
      await t.tap(find.byKey(const ValueKey('feed-search')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'warung');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Warung Pak Ali'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feed-search-for')));
      await t.pumpAndSettle();
      expect(cardKeys(t), ['feed-place-b-2']);

      await t.tap(find.byKey(const ValueKey('feed-search')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'rendang');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Rendang Daging'));
      await t.pumpAndSettle();
      expect(find.text('recipe d-1'), findsOneWidget);
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
