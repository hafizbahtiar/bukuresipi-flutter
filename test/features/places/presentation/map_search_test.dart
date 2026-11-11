import 'dart:async';

import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_search.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../places_fixtures.dart';

void main() {
  test('map search finds pinned branches by name or label, any case, and skips unpinned ones', () {
    final places = [
      place(id: 'p-1', name: 'Nasi Kandar Pelita'),
      place(id: 'p-2', name: 'Kopi Tiam'),
      place(id: 'p-3', name: 'Nasi Lemak Unpinned', lat: null),
    ];
    expect(searchPins(places, '  NASI ').map((h) => h.$1.id), ['p-1']);
    expect(searchPins(places, 'tiam ampang').map((h) => h.$1.id), ['p-2']);
    expect(searchPins(places, ''), isEmpty);
    expect(searchPins(places, 'sushi'), isEmpty);
  });

  testWidgets(
    'the bar asks the server: ours while typing, OpenStreetMap on Search; a pick is returned and the bar empties',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final asked = <(String, bool)>[];
      Object? picked;
      const mart = PlaceHit(
        poiId: 'osm:N42',
        name: 'FamilyMart',
        lat: 3.14,
        lng: 101.7,
        distanceM: 1200,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [Notebook.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MapSearchBar(
              places: const [],
              search: (q, {required submit}) async {
                asked.add((q, submit));
                return submit ? const [mart] : const <PlaceHit>[];
              },
              onPicked: (hit) => picked = hit,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('map-search-results')), findsNothing);
      await t.enterText(find.byType(TextField), 'family mart');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(asked, [('family mart', false)]);
      expect(find.text(l.mapSearchPress), findsOneWidget);

      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(asked.last, ('family mart', true));
      expect(find.text('1.2 km'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('search-hit-osm:N42')));
      await t.pumpAndSettle();
      expect(picked, same(mart));
      expect(find.byKey(const ValueKey('map-search-results')), findsNothing);
      expect(find.text('family mart'), findsNothing);
    },
  );

  testWidgets('back closes the results before it leaves the page', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [Notebook.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: MapSearchBar(
            places: [place(id: 'p-1', name: 'Nasi Kandar Pelita')],
            search: (q, {required submit}) async => const <PlaceHit>[],
            onPicked: (_) {},
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'nasi');
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(find.text('Nasi Kandar Pelita'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-search-results')), findsNothing);
  });

  testWidgets(
    'the glass turns into ✕ while typing and clears; back closes the search, then leaves the page',
    (t) async {
      final router = GoRouter(
        initialLocation: '/map',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/map',
            builder: (_, _) => Scaffold(
              body: MapSearchBar(
                places: const [],
                search: (q, {required submit}) async => const <PlaceHit>[],
                onPicked: (_) {},
              ),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: const [Notebook.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      );
      expect(find.byKey(const ValueKey('map-search-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-search-clear')), findsNothing);
      await t.enterText(find.byType(TextField), 'nasi');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('map-search-clear')));
      await t.pumpAndSettle();
      expect(find.text('nasi'), findsNothing);
      expect(find.byKey(const ValueKey('map-search-icon')), findsOneWidget);

      await t.tap(
        find.byKey(const ValueKey('map-search-back')),
      ); // still focused: closes the search
      await t.pumpAndSettle();
      expect(find.text('home'), findsNothing);
      await t.tap(
        find.byKey(const ValueKey('map-search-back')),
      ); // nothing open: leaves
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets(
    'while the server is asked and nothing matched yet, loading rows show; the answer replaces them',
    (t) async {
      final answer = Completer<List<PlaceHit>>();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [Notebook.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MapSearchBar(
              places: const [],
              search: (q, {required submit}) => answer.future,
              onPicked: (_) {},
            ),
          ),
        ),
      );
      await t.enterText(find.byKey(const ValueKey('map-search')), 'family');
      await t.pump(const Duration(milliseconds: 350)); // past the typing pause
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('search-loading-0')), findsOneWidget);

      answer.complete(const [
        PlaceHit(
          poiId: 'osm:N42',
          name: 'FamilyMart',
          lat: 3.14,
          lng: 101.7,
          distanceM: 1200,
        ),
      ]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-loading-0')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('FamilyMart'), findsOneWidget);
    },
  );
}
