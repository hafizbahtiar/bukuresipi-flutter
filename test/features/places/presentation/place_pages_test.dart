import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/place_detail_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
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

void main() {
  late FakePlaces repo;
  late PlacesController places;
  late FakeShares fakeShares;
  var shared = <Share>[];

  Future<void> pump(WidgetTester t, Widget page, {String role = 'user'}) async {
    places = PlacesController(repo);
    await places.load();
    final recipes = RecipesController(FakeRecipes());
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
        const Share(id: 's1', status: 'processing', kind: 'unknown'),
        const Share(
          id: 's2',
          status: 'failed',
          kind: 'unknown',
          error: 'ai_failed',
        ),
      ];
      await pump(t, const PlacesListPage());
      await t.pump();
      expect(find.text('Reading a post you shared…'), findsOneWidget);
      expect(find.textContaining('could not read this post'), findsOneWidget);
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
}
