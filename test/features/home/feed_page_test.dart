import 'dart:async';

import 'package:bukuresipi_flutter/features/home/presentation/feed_page.dart';
import 'package:bukuresipi_flutter/core/network/update_gate.dart';
import 'package:bukuresipi_flutter/features/home/presentation/widgets/feed_card.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/widgets/share_image.dart';
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
  late FakeRecipes recipes;

  Future<void> pump(
    WidgetTester t, {
    bool located = true,
    int community = 1,
    RatingSummary? rating,
    UpdateGate? update,
    bool empty = false, // no restaurants nearby, no recipes
    bool locating = false, // the location answer never comes: still loading
    bool settle = true,
    Completer<void>? dishesGate,
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
    recipes = FakeRecipes()
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
        Dish(id: 'd-2', name: 'Kari Ayam', cover: 'cv-1'),
      ];
    recipes.dishesGate = dishesGate;
    if (empty) {
      places.nearbyResults = [];
      recipes
        ..communityList = []
        ..dishList = const [];
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => FeedPage(
            locate: () => locating
                ? Completer<({double lat, double lng})?>().future
                : Future.value(located ? (lat: 3.15, lng: 101.7) : null),
          ),
        ),
        GoRoute(path: '/map', builder: (_, _) => const Text('the map')),
        GoRoute(
          path: '/shopping',
          builder: (_, _) => const Text('the shopping list'),
        ),
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
          ChangeNotifierProvider.value(
            value: update ?? UpdateGate(playHasUpdate: () async => false),
          ),
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
    if (settle) await t.pumpAndSettle();
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
        'feed-dish-d-2',
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
      // The owner set a cover: the dish card shows it.
      final dishPhoto = t.widget<ShareFill>(
        inCard('feed-dish-d-2', find.byType(ShareFill)),
      );
      expect([dishPhoto.id, dishPhoto.recipeId], ['cv-1', 'd-2']);
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

  testWidgets(
    'a dish edited on its page: its Home card takes the new name and photo',
    (t) async {
      await pump(t);
      t.element(find.byType(FeedPage)).read<RecipesController>().edited.value =
          recipeDetail(id: 'd-1', name: 'Rendang Tok', cover: 'cv-9');
      await t.pump();
      final card = find.byKey(const ValueKey('feed-dish-d-1'));
      expect(
        find.descendant(of: card, matching: find.text('Rendang Tok')),
        findsOneWidget,
      );
      expect(
        t
            .widget<ShareFill>(
              find.descendant(of: card, matching: find.byType(ShareFill)),
            )
            .id,
        'cv-9',
      );
    },
  );

  testWidgets('a dish deleted on its page leaves Home', (t) async {
    await pump(t);
    t.element(find.byType(FeedPage)).read<RecipesController>().removed.value =
        'd-1';
    await t.pump();
    expect(find.byKey(const ValueKey('feed-dish-d-1')), findsNothing);
    expect(find.byKey(const ValueKey('feed-dish-d-2')), findsOneWidget);
  });

  testWidgets(
    'a place edited anywhere: the Home restaurant cards fetch again, with the new name',
    (t) async {
      await pump(t);
      places.nearbyResults = [
        nearbyBranch(
          branchId: 'b-2',
          name: 'Warung Pak Ali Baru',
          distanceM: 300,
        ),
      ];
      await t
          .element(find.byType(FeedPage))
          .read<PlacesController>()
          .setRestaurantCover('r-1', null);
      await t.pumpAndSettle();
      expect(find.text('Warung Pak Ali Baru'), findsOneWidget);
      expect(find.text('Kedai Sederhana'), findsNothing);
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

  testWidgets('the shopping button opens the shopping list', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('feed-shopping')));
    await t.pumpAndSettle();
    expect(find.text('the shopping list'), findsOneWidget);
  });

  testWidgets('a newer version on Google Play shows the Update chip', (
    t,
  ) async {
    final update = UpdateGate(playHasUpdate: () async => true);
    await pump(t, update: update);
    expect(find.byKey(const ValueKey('update-chip')), findsNothing);
    await update.check();
    await t.pump();
    expect(find.widgetWithText(ActionChip, 'Update'), findsOneWidget);
    // No Play listing (debug build, sideloaded APK): the check fails quietly, no chip.
    final none = UpdateGate(
      playHasUpdate: () async => throw Exception('no Play'),
    );
    await none.check();
    expect(none.available, isFalse);
  });

  testWidgets(
    'first load: skeleton cards fill the grid, no spinner and no empty state',
    (t) async {
      // Recipes do not wait for location: with none yet and location still being asked, the grid is all skeleton.
      await pump(t, empty: true, locating: true, settle: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(FeedCardSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('feed-empty')), findsNothing);
    },
  );

  testWidgets(
    'nothing at all: the welcome empty state, Share a post and Open the map',
    (t) async {
      await pump(t, empty: true);
      expect(find.byType(FeedCardSkeleton), findsNothing);
      expect(find.byKey(const ValueKey('feed-empty')), findsOneWidget);
      expect(find.text(l.feedEmptyTitle), findsOneWidget);
      expect(find.text(l.feedEmptyShare), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feed-empty-secondary')));
      await t.pumpAndSettle();
      expect(find.text('the map'), findsOneWidget);
    },
  );

  testWidgets(
    'filters that hide everything say so, and Clear filters brings back the plain feed',
    (t) async {
      await pump(t, empty: true);
      await t.tap(find.byKey(const ValueKey('feed-kind-restaurants')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('feed-empty-filters')), findsOneWidget);
      expect(find.text(l.feedEmptyFilterTitle), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feed-empty-primary')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('feed-empty-filters')), findsNothing);
      expect(find.byKey(const ValueKey('feed-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'a search that finds nothing names the word, and Clear search empties it',
    (t) async {
      await pump(t, empty: true);
      await t.tap(find.byKey(const ValueKey('feed-search')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'sushi');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('feed-search-for')));
      await t.pumpAndSettle();
      expect(find.text(l.feedEmptySearchTitle('sushi')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feed-empty-primary')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('feed-empty-search')), findsNothing);
      expect(find.byKey(const ValueKey('feed-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'pull to refresh keeps the cards on screen until the new ones arrive',
    (t) async {
      await pump(t);
      final before = cardKeys(t);
      expect(before, isNotEmpty);
      recipes.communityGate = Completer();
      await t.fling(find.byType(CustomScrollView), const Offset(0, 400), 1500);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
        expect(cardKeys(t), before); // never blank, never skeleton
        expect(find.byType(FeedCardSkeleton), findsNothing);
        expect(find.byKey(const ValueKey('feed-empty')), findsNothing);
      }
      recipes.communityGate!.complete();
      await t.pumpAndSettle();
      expect(cardKeys(t), before);
    },
  );

  testWidgets(
    'no empty state between pages: no community recipes, dishes still coming',
    (t) async {
      final gate = Completer<void>();
      await pump(t, empty: true, dishesGate: gate, settle: false);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey('feed-empty')), findsNothing);
      }
      expect(find.byType(FeedCardSkeleton), findsWidgets);
      gate.complete();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('feed-empty')), findsOneWidget);
    },
  );
}
