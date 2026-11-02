import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/place_detail_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../places_fixtures.dart';

void main() {
  late FakePlaces repo;
  late PlacesController places;

  Future<void> pump(WidgetTester t, Widget page, {String role = 'user'}) async {
    places = PlacesController(repo);
    await places.load();
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
          ChangeNotifierProvider.value(value: auth),
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
    final button = find.text('Remove from my book');
    await t.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(button);
    await t.pumpAndSettle();
    expect(repo.removed, isEmpty);
    await t.tap(find.widgetWithText(TextButton, 'Remove'));
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
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(repo.deletedBranches, ['b-1']);
  });
}
