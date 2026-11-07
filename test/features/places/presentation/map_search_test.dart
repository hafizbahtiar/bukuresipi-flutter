import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_search.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'other places come from the server: ours while typing, OpenStreetMap on Search; a pick is returned',
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showSearch<Object?>(
                context: context,
                delegate: MapSearch(const [], (q, {required submit}) async {
                  asked.add((q, submit));
                  return submit ? const [mart] : const <PlaceHit>[];
                }, l),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'family mart');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(asked, [('family mart', false)]);
      expect(find.text(l.mapSearchPress), findsOneWidget);

      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(asked.last, ('family mart', true));
      await t.tap(find.byKey(const ValueKey('search-hit-osm:N42')));
      await t.pumpAndSettle();
      expect(picked, same(mart));
    },
  );
}
