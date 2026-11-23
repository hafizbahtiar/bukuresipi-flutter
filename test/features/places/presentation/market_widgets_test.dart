import 'package:bukuresipi_flutter/features/places/domain/market.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/branch_edit_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/market_days.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/market_days_editor.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/market_layers.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/market_sheet.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../places_fixtures.dart';

const sat = MarketDay(day: 6, opens: '17:00', closes: '22:00');

Market market({String? saved, Map<String, dynamic>? shape}) => Market(
  placeId: 'p',
  branchId: 'b',
  name: 'Pasar Malam SS2',
  subcategory: 'pasar_malam',
  lat: 3.1,
  lng: 101.6,
  distanceM: 500,
  schedule: const [sat],
  shape: shape,
  savedPlaceId: saved,
);

void main() {
  late FakePlaces repo;
  late PlacesController places;
  setUp(() {
    repo = FakePlaces();
    places = PlacesController(repo);
  });

  Future<void> pump(WidgetTester t, Widget child, {String lang = 'en'}) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: places,
        child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: Scaffold(body: child),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  group('MarketDaysList', () {
    testWidgets('days and hours in the app language', (t) async {
      await pump(t, const MarketDaysList(schedule: [sat]), lang: 'ms');
      expect(find.text('Sabtu'), findsOneWidget);
      expect(find.textContaining('5:00'), findsOneWidget);
    });

    testWidgets('no days = not known, never a guess', (t) async {
      await pump(t, const MarketDaysList(schedule: []));
      expect(find.text('Days not known yet.'), findsOneWidget);
    });
  });

  group('marketGeoJson', () {
    test('a dot for every market, a shape only when it is one we draw', () {
      final line = {
        'type': 'LineString',
        'coordinates': [
          [101.6, 3.1],
          [101.7, 3.2],
        ],
      };
      final features =
          marketGeoJson([
                market(shape: line),
                market(shape: {'type': 'GeometryCollection'}),
                market(),
              ])['features']
              as List;
      expect(features.length, 4);
      expect(features.first['id'], 'b#shape');
      expect(marketIdOf('b#shape'), 'b');
      expect(marketIdOf('b'), 'b');
    });
  });

  group('MarketSheet', () {
    testWidgets('Save keeps the sheet and tells the map', (t) async {
      repo.saveBranchResult = place(id: 'saved-1');
      String? saved;
      await pump(
        t,
        MarketSheet(
          market: market(),
          places: places,
          onSaved: (p) => saved = p,
        ),
      );
      await t.tap(find.byKey(const ValueKey('market-save')));
      await t.pumpAndSettle();
      expect(repo.savedBranches, ['b']);
      expect(saved, 'saved-1');
    });

    testWidgets('a failed save says so and can be tried again', (t) async {
      repo.saveBranchError = Exception('offline');
      await pump(
        t,
        MarketSheet(market: market(), places: places, onSaved: (_) {}),
      );
      await t.tap(find.byKey(const ValueKey('market-save')));
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        t
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('market-save')),
            )
            .enabled,
        isTrue,
      );
    });

    testWidgets('already saved: Open instead of Save', (t) async {
      await pump(
        t,
        MarketSheet(
          market: market(saved: 'x'),
          places: places,
          onSaved: (_) {},
        ),
      );
      expect(find.byKey(const ValueKey('market-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('market-save')), findsNothing);
    });
  });

  group('MarketDaysEditor', () {
    Future<void> save(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('market-save-days')));
      await t.pumpAndSettle();
    }

    testWidgets('adds a day and saves the list sorted', (t) async {
      await pump(
        t,
        const SingleChildScrollView(
          child: MarketDaysEditor(branchId: 'b', initial: [sat]),
        ),
      );
      await t.tap(find.byKey(const ValueKey('market-add')));
      await t.pumpAndSettle();
      await save(t);
      final (id, days) = repo.setSchedules.single;
      expect(id, 'b');
      expect(days.map((d) => d.day), [6, 7]);
      expect(find.text('Market days saved.'), findsOneWidget);
    });

    testWidgets('the same day and opening time is refused before the call', (
      t,
    ) async {
      await pump(
        t,
        const SingleChildScrollView(
          child: MarketDaysEditor(branchId: 'b', initial: [sat, sat]),
        ),
      );
      await save(t);
      expect(repo.setSchedules, isEmpty);
      expect(
        find.text('Two rows have the same day and opening time.'),
        findsOneWidget,
      );
    });

    testWidgets('removing every day saves an empty list', (t) async {
      await pump(
        t,
        const SingleChildScrollView(
          child: MarketDaysEditor(branchId: 'b', initial: [sat]),
        ),
      );
      await t.tap(find.byKey(const ValueKey('market-remove-0')));
      await t.pumpAndSettle();
      expect(find.text('Days not known yet.'), findsOneWidget);
      await save(t);
      expect(repo.setSchedules.single.$2, isEmpty);
    });

    testWidgets('a failed save keeps what was typed', (t) async {
      repo.setScheduleError = Exception('offline');
      await pump(
        t,
        const SingleChildScrollView(
          child: MarketDaysEditor(branchId: 'b', initial: [sat]),
        ),
      );
      await t.tap(find.byKey(const ValueKey('market-add')));
      await t.pumpAndSettle();
      await save(t);
      expect(find.byKey(const ValueKey('market-row-1')), findsOneWidget);
      expect(find.text('Market days saved.'), findsNothing);
    });
  });

  group('Edit branch', () {
    Widget page({bool owner = true}) => BranchEditPage(
      placeId: 'p',
      branch: const Branch(id: 'b', label: 'Pasar Malam SS2'),
      canEditShared: owner,
      onSave: (_, _) async {},
    );

    testWidgets('the owner gets Days for a market, with what is saved', (
      t,
    ) async {
      repo.schedule = (market: true, days: const [sat]);
      await pump(t, page());
      await t.tap(find.text('Days'));
      await t.pumpAndSettle();
      expect(find.text('Saturday'), findsOneWidget);
    });

    testWidgets('no Days for a place that is not a market, or for a user', (
      t,
    ) async {
      await pump(t, page());
      expect(find.text('Days'), findsNothing);
      repo.schedule = (market: true, days: const [sat]);
      await pump(t, page(owner: false));
      expect(find.text('Days'), findsNothing);
    });
  });
}
