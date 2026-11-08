import 'package:bukuresipi_flutter/core/widgets/notebook.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/place_detail_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_edit_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bukuresipi_flutter/features/shares/domain/share.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';

import '../../../fakes.dart';
import '../../shares/presentation/share_intake_test.dart' show FakeShares;
import '../places_fixtures.dart';
import '../../recipes/recipes_fixtures.dart';

/// Space between the map picker and the search box below it.
double spacing(WidgetTester t) =>
    t.getTopLeft(find.byKey(const ValueKey('pin-search-query'))).dy -
    t.getBottomLeft(find.text('AWS (Grab)')).dy;

void main() {
  late FakePlaces repo;
  late PlacesController places;
  late FakeShares fakeShares;
  late FakeRecipes fakeRecipes;
  var shared = <Share>[];

  Future<void> pump(WidgetTester t, Widget page, {String role = 'user'}) async {
    places = PlacesController(repo);
    await places.load();
    final recipes = RecipesController(fakeRecipes = FakeRecipes());
    await recipes.load();
    final auth = AuthController(
      FakeAuthRepository()
        ..session = true
        ..meResult = User(
          id: 'u-1',
          email: 'a@example.com',
          name: null,
          role: role,
          lang: 'en',
          emailVerified: true,
        ),
    );
    await auth.restore();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: recipes),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => RecentShares(
              fakeShares = FakeShares()..recentList = shared,
              onFinished: () async {},
            )..load(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: page,
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('the book lists saved places; a place without a pin says so', (
    t,
  ) async {
    repo = FakePlaces()
      ..places = [
        place(id: 'a', name: 'Kedai Kopi Ah Seng'),
        place(id: 'b', name: 'Mee Rebus Haji', lat: null),
      ];
    await pump(t, const PlacesListPage());
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
    expect(find.text('Mee Rebus Haji'), findsOneWidget);
    expect(find.text('Location not found yet'), findsOneWidget);
  });

  testWidgets('pulling the book down reloads places, recipes and shares', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a', name: 'Kedai Kopi Ah Seng')];
    await pump(t, const PlacesListPage());
    fakeRecipes.recipes = [recipe(id: 'r1', name: 'Ayam Masak Merah')];
    await t.fling(find.text('Kedai Kopi Ah Seng'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(find.text('Ayam Masak Merah'), findsOneWidget);
  });

  testWidgets(
    'the book has New recipe (moved from the Recipes tab): it opens the empty editor',
    (t) async {
      repo = FakePlaces();
      await pump(t, const PlacesListPage());
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      expect(find.byType(RecipeEditPage), findsOneWidget);
    },
  );

  testWidgets('an empty book tells the user how to add to it', (t) async {
    repo = FakePlaces();
    await pump(t, const PlacesListPage());
    expect(find.textContaining('Share a TikTok'), findsOneWidget);
  });

  testWidgets('an unreadable share can be retried or removed', (t) async {
    repo = FakePlaces();
    shared = [
      Share(
        id: 's1',
        status: 'done',
        kind: 'other',
        gaps: const ['unreadable'],
      ),
    ];
    await pump(t, const PlacesListPage());
    await t.pump(const Duration(milliseconds: 400)); // the row slides in
    expect(find.text('Try again'), findsOneWidget);

    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(fakeShares.retried, ['s1']);

    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Remove this post from your list'),
      findsOneWidget,
    );
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await t.pumpAndSettle();
    expect(fakeShares.dismissed, ['s1']);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets(
    'halal is shown as the post\'s quote with its source, never as a badge',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      expect(find.text('What the post says about halal'), findsOneWidget);
      expect(find.textContaining('Halal ya'), findsOneWidget);
      expect(find.text('Open the post'), findsOneWidget);
      expect(find.textContaining('not a halal certificate'), findsOneWidget);
      expect(find.text('Halal'), findsNothing);
    },
  );

  testWidgets(
    'the place links to the post the user shared, when there is one',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(id: 'a', sourceUrl: 'https://www.tiktok.com/@makan/video/2'),
          place(id: 'b'),
        ];
      await pump(t, const PlaceDetailPage(id: 'a'));
      expect(find.text('Open your post'), findsOneWidget);
      await pump(t, const PlaceDetailPage(id: 'b'));
      expect(find.text('Open your post'), findsNothing);
    },
  );

  testWidgets('no claim, no halal section', (t) async {
    repo = FakePlaces()..places = [place(id: 'a', halal: null)];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.text('What the post says about halal'), findsNothing);
  });

  testWidgets('remove asks first, then takes the place off the book', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    // In the floating dock: always in reach, no scrolling.
    await t.tap(find.byTooltip('Remove from my book'));
    await t.pumpAndSettle();
    expect(repo.removed, isEmpty);
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await t.pumpAndSettle();
    expect(repo.removed, ['a']);
    expect(places.places, isEmpty);
  });

  testWidgets('a branch without a pin offers Find location; a hit says so', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a', lat: null)];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.text('Set on map'), findsOneWidget);
    await t.tap(find.text('Find location'));
    await t.pumpAndSettle();
    expect(repo.located, ['b-1']);
    expect(find.text('Found it. It is on your map now.'), findsOneWidget);
    expect(find.widgetWithText(AlertDialog, 'Set on map'), findsNothing);
  });

  testWidgets('Find location says plainly when it was already tried today', (
    t,
  ) async {
    repo = FakePlaces()
      ..places = [place(id: 'a', lat: null)]
      ..locateResult = LocateResult.triedToday;
    await pump(t, const PlaceDetailPage(id: 'a'));
    await t.tap(find.text('Find location'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('already looked for this shop today'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AlertDialog, 'Set on map'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'OK'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('only the owner can delete a branch, after confirming', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.byTooltip('Delete branch'), findsNothing);

    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Delete branch'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(repo.deletedBranches, ['b-1']);
  });

  testWidgets('the owner edits a branch from the place page', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    expect(find.byTooltip('Edit branch'), findsOneWidget);

    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    expect(find.text('This branch is shared by every user.'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('branch-label')), 'Kedai Baru');
    await t.enterText(
      find.byKey(const ValueKey('branch-address')),
      'Jalan Baru',
    );
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'Kedai Baru');
    expect(repo.branchUpdates.single.address, 'Jalan Baru');
    expect(repo.branchUpdates.single.lat, isNull);
    expect(repo.branchUpdates.single.lng, isNull);
    expect(repo.branchUpdates.single.scope, BranchEditScope.shared);
  });

  testWidgets('town and state are dropdowns from the server list', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    TextEditingController ctl(String key) => t
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!;
    // A town picked first brings its state.
    final city = find.byKey(const ValueKey('branch-city'));
    await t.ensureVisible(city);
    await t.tap(city);
    await t.pumpAndSettle();
    await t.tap(find.text('Ketereh').last);
    await t.pumpAndSettle();
    expect(ctl('branch-state').text, 'Kelantan');
    // Another state clears a town that is not in it; its towns are the only ones listed.
    final state = find.byKey(const ValueKey('branch-state'));
    await t.ensureVisible(state);
    await t.tap(find.descendant(of: state, matching: find.byType(IconButton)));
    await t.pumpAndSettle();
    await t.tap(find.text('Selangor').last);
    await t.pumpAndSettle();
    expect(ctl('branch-city').text, '');
    await t.tap(city);
    await t.pumpAndSettle();
    expect(find.text('Kajang'), findsWidgets);
    expect(find.text('Ketereh'), findsNothing);
    await t.tap(find.text('Kajang').last);
    await t.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(repo.branchUpdates.single.city, 'Kajang');
    expect(repo.branchUpdates.single.state, 'Selangor');
  });

  testWidgets('a user can edit a branch for themselves only', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));

    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    expect(find.text('Only you will see these changes.'), findsOneWidget);
    expect(find.text('Who sees this edit?'), findsNothing);
    expect(find.text('Suggest with AI'), findsNothing);

    await t.enterText(find.byKey(const ValueKey('branch-label')), 'My Kedai');
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'My Kedai');
    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
    expect(find.text('Saved for you.'), findsOneWidget);
  });

  testWidgets('the owner can choose Just me before saving', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    expect(find.text('Who sees this edit?'), findsOneWidget);

    await t.tap(find.text('Just me'));
    await t.pumpAndSettle();
    expect(find.text('Only you will see these changes.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('branch-label')), 'Owner only');
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
  });

  testWidgets('a branch row shows its rating as one line, without overflow', (
    t,
  ) async {
    repo = FakePlaces()
      ..places = [
        place(
          id: 'a',
          rating: const RatingSummary(average: 4.3, count: 7, canRate: true),
        ),
      ]
      ..ratingResult = const RatingSummary(
        average: 4.3,
        count: 7,
        mine: 4,
        canRate: true,
      );
    t.view.physicalSize = const Size(320 * 3, 640 * 3); // a small phone
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.byKey(const ValueKey('rating-star-4')), findsNothing);
    expect(find.textContaining('4.3 · 7 ratings'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the owner reviews an AI draft before saving it', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    repo.suggestion = const BranchSuggestion(
      draft: BranchDraft(
        label: 'AI Label',
        address: 'AI Address',
        city: 'AI City',
        state: 'Selangor',
        lat: 2.991234,
        lng: 101.791234,
      ),
      sources: ['nominatim'],
      aiUsed: true,
      changed: true,
      summary: 'Cleaned from the map.',
    );
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();

    final suggest = find.text('Suggest with AI');
    await t.ensureVisible(suggest);
    await t.tap(suggest);
    await t.pumpAndSettle();

    expect(repo.suggested, ['b-1']);
    expect(find.text('AI draft — review before saving'), findsOneWidget);
    expect(find.text('Source: nominatim'), findsOneWidget);
    expect(
      find.text('Filled into the fields below — review before saving.'),
      findsOneWidget,
    );
    expect(find.text('AI'), findsWidgets);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('branch-label')))
          .controller!
          .text,
      'AI Label',
    );
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('branch-lat')))
          .controller!
          .text,
      '2.991234',
    );

    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'AI Label');
    expect(repo.branchUpdates.single.lat, 2.991234);
    expect(repo.branchUpdates.single.lng, 101.791234);
    expect(repo.branchUpdates.single.scope, BranchEditScope.shared);
  });

  testWidgets('the owner can type coordinates instead of using the map', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();

    final lat = find.byKey(const ValueKey('branch-lat'));
    final lng = find.byKey(const ValueKey('branch-lng'));
    await t.ensureVisible(lat);
    await t.enterText(lat, '2.991234');
    await t.ensureVisible(lng);
    await t.enterText(lng, '101.791234');
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.lat, 2.991234);
    expect(repo.branchUpdates.single.lng, 101.791234);
  });

  testWidgets('a user pastes a Google Maps link and the pin is filled in', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();

    final link = find.byKey(const ValueKey('branch-maps-link'));
    await t.ensureVisible(link);
    await t.enterText(link, 'https://maps.app.goo.gl/AbC123');
    await t.tap(find.text('Use link'));
    await t.pumpAndSettle();

    expect(repo.mapsLinks, ['https://maps.app.goo.gl/AbC123']);
    String field(String key) =>
        t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(field('branch-lat'), '3.199464');
    expect(field('branch-lng'), '101.695650');
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(repo.branchUpdates.single.lat, 3.199464);
    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
  });

  testWidgets('the owner sees every pin the draft found and can pick one', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    repo.suggestion = const BranchSuggestion(
      draft: BranchDraft(lat: 3.2001, lng: 101.6901),
      sources: ['here'],
      aiUsed: false,
      changed: true,
      warnings: ['The pins found are up to 550 m apart'],
      candidates: [
        (
          source: 'here',
          lat: 3.2001,
          lng: 101.6901,
          address: null,
          fromDraftM: 0,
        ),
        (
          source: 'grab',
          lat: 3.205,
          lng: 101.69,
          address: null,
          fromDraftM: 545,
        ),
      ],
    );
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    final suggest = find.text('Suggest with AI');
    await t.ensureVisible(suggest);
    await t.tap(suggest);
    await t.pumpAndSettle();

    expect(find.text('Pins found'), findsOneWidget);
    expect(find.textContaining('545 m'), findsOneWidget);
    final use = find.descendant(
      of: find.byKey(const ValueKey('pin-grab')),
      matching: find.text('Use'),
    );
    await t.ensureVisible(use);
    await t.tap(use);
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('branch-lat')))
          .controller!
          .text,
      '3.205000',
    );
  });

  testWidgets('the owner picks a map, searches it and uses a hit', (t) async {
    repo = FakePlaces()
      ..places = [place(id: 'a')]
      ..pinHits = const [
        (
          lat: 3.1591,
          lng: 101.7122,
          address: 'P&C Kitchen, Jalan Ampang, Kuala Lumpur',
          city: 'Kuala Lumpur',
          state: 'Wilayah Persekutuan Kuala Lumpur',
          source: 'grab',
        ),
      ];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    // Picking a map searches it at once.
    final osm = find.text('OpenStreetMap');
    await t.ensureVisible(osm);
    await t.tap(osm);
    await t.pumpAndSettle();
    expect(repo.pinSearches.last.$2, 'osm');
    await t.tap(find.text('AWS (Grab)'));
    await t.pumpAndSettle();
    expect(repo.pinSearches.last.$2, 'grab');
    // The first map's default words are not sent to the next: each map gets its own.
    expect(repo.pinSearches.last.$3, isNull);
    expect(spacing(t), greaterThanOrEqualTo(8));
    final use = find.descendant(
      of: find.byKey(const ValueKey('pin-hit-0')),
      matching: find.text('Use'),
    );
    await t.ensureVisible(use);
    await t.tap(use);
    await t.pumpAndSettle();
    String field(String key) => t
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
            matchRoot: true,
          ),
        )
        .controller!
        .text;
    expect(field('branch-lat'), '3.159100');
    expect(field('branch-city'), 'Kuala Lumpur');
    expect(field('branch-state'), 'Wilayah Persekutuan Kuala Lumpur');
    expect(
      field('pin-search-query'),
      'Shop, Kuala Lumpur',
    ); // what was asked, to change and search again
  });

  testWidgets('a pinned place has a map button that opens the map on its pin', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a', lat: 3.15)];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.byKey(const ValueKey('place-map')), findsOneWidget);
  });

  testWidgets(
    'a report can take the pin from a Google Maps link, sent with the link',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await t.tap(find.text('Report').last);
      await t.pumpAndSettle();
      final link = find.byKey(const ValueKey('report-maps-link'));
      await t.ensureVisible(link);
      await t.enterText(link, 'https://maps.app.goo.gl/AbC123');
      await t.tap(find.descendant(of: link, matching: find.text('Use link')));
      await t.pumpAndSettle();
      expect(find.text('3.199464, 101.695650'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Report');
      await t.ensureVisible(send);
      await t.tap(send);
      await t.pumpAndSettle();
      final r = repo.reports.single;
      expect(r.lat, closeTo(3.1994645, 1e-9));
      expect(r.lng, closeTo(101.6956504, 1e-9));
      expect(r.note, 'https://maps.app.goo.gl/AbC123');
    },
  );

  testWidgets('a user does not see the map search', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await t.tap(find.byTooltip('Edit branch'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('pin-search-query')), findsNothing);
  });

  testWidgets('the owner can check a restaurant\'s branches; users cannot', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.text('Check branches'), findsNothing);

    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await t.tap(find.text('Check branches'));
    await t.pumpAndSettle();
    expect(repo.tidied, [places.byId('a')!.restaurant.id]);
    expect(find.text('Branches checked: 1 merged, 1 removed.'), findsOneWidget);
  });

  testWidgets(
    'the book shows a post still being read, and one that could not be read',
    (t) async {
      repo = FakePlaces();
      shared = [
        const Share(
          id: 's1',
          status: 'processing',
          kind: 'unknown',
          platform: 'tiktok',
          attempts: 1,
        ),
        const Share(
          id: 's2',
          status: 'failed',
          kind: 'unknown',
          error: 'ai_failed',
        ),
      ];
      await pump(t, const PlacesListPage());
      await t.pump(const Duration(milliseconds: 400)); // the rows slide in
      expect(find.text('Reading your TikTok post…'), findsOneWidget);
      expect(find.text('Reading the caption and the page'), findsOneWidget);
      expect(
        find.text('Something went wrong while reading it. Try again.'),
        findsOneWidget,
      );
      // Why, for whoever is looking into it.
      expect(find.textContaining('ai_failed'), findsOneWidget);
      shared = [];
    },
  );

  testWidgets(
    'Save note in the dock is off until the note changes, then saves it',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await t.tap(find.byTooltip('Save note'));
      await t.pump();
      expect(repo.notes, isEmpty);
      await t.enterText(find.byType(TextField), 'Order the ayam goreng');
      await t.pump();
      await t.tap(find.byTooltip('Save note'));
      await t.pumpAndSettle();
      expect(repo.notes, {'a': 'Order the ayam goreng'});
    },
  );

  testWidgets(
    'with the keyboard open the dock sits above it (Save note stays in reach)',
    (t) async {
      t.view.physicalSize = const Size(1080, 2280);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      t.view.viewInsets = const FakeViewPadding(
        bottom: 900,
      ); // 300 logical px of keyboard
      await t.pumpAndSettle();
      final screen = 2280 / 3;
      expect(
        t.getBottomLeft(find.byTooltip('Save note')).dy,
        lessThanOrEqualTo(screen - 300),
      );
    },
  );

  testWidgets(
    'typing a note with the keyboard open: the note shows above the keyboard and the dock',
    (t) async {
      t.view.physicalSize = const Size(
        1080,
        1800,
      ); // a short phone: the note starts below the fold
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await t.scrollUntilVisible(
        find.byType(TextField),
        200,
      ); // the user scrolls down to the note
      await t.showKeyboard(find.byType(TextField));
      t.view.viewInsets = const FakeViewPadding(
        bottom: 900,
      ); // 300 logical px of keyboard
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Sedap, datang lagi');
      await t.pumpAndSettle();
      final dockTop = t.getTopLeft(find.byType(ActionDock)).dy;
      final field = t.getRect(find.byType(TextField));
      expect(
        field.bottom,
        lessThanOrEqualTo(dockTop),
        reason: 'the note is under the dock or keyboard',
      );
      expect(field.top, greaterThanOrEqualTo(0));
    },
  );
}
