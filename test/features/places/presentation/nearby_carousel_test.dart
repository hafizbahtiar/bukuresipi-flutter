import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/nearby_carousel.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

Widget app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('ms')],
  home: Scaffold(body: home),
);

List<NearbyBranch> many(int n) => [
  for (var i = 1; i <= n; i++)
    nearbyBranch(branchId: 'b$i', name: 'Kedai $i', lat: 3.15 + i / 1000),
];

void main() {
  testWidgets('nearby branches are compact horizontal cards with info', (
    t,
  ) async {
    final tapped = <String>[];
    await t.pumpWidget(
      app(
        NearbyCarousel(
          places: [
            nearbyBranch(name: 'Kedai Dekat', distanceM: 350),
            nearbyBranch(branchId: 'b-2', name: 'Kedai Jauh', distanceM: 2400),
          ],
          selectedBranchId: 'b-1',
          onTap: (p) => tapped.add(p.branchId),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Kedai Dekat'), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('Kedai Jauh'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('Melayu'), findsNWidgets(2));
    expect(find.textContaining('Halal ya'), findsNWidgets(2));
    expect(find.text('Kedai Sederhana Bangsar'), findsNWidgets(2));
    expect(find.text('Jalan Telawi'), findsNWidgets(2));
    expect(
      t.widget<ListView>(find.byType(ListView)).scrollDirection,
      Axis.horizontal,
    );

    await t.tap(find.text('Kedai Dekat'));
    expect(tapped, ['b-1']);
  });

  testWidgets('tapping a side card focuses it; tapping again opens detail', (
    t,
  ) async {
    final selected = <String>[];
    final opened = <String>[];
    await t.pumpWidget(
      app(
        NearbyCarousel(
          places: many(4),
          selectedBranchId: 'b1',
          onTap: (p) => opened.add(p.branchId),
          onSelected: (p) => selected.add(p.branchId),
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('nearby-card-b2')));
    await t.pumpAndSettle();
    expect(selected, ['b2']);
    expect(opened, isEmpty);

    await t.tap(find.byKey(const ValueKey('nearby-card-b2')));
    await t.pumpAndSettle();
    expect(opened, ['b2']);
  });

  testWidgets('a saved card is marked Saved', (t) async {
    await t.pumpWidget(
      app(
        NearbyCarousel(
          places: [nearbyBranch(saved: true, placeId: 'p-1')],
          onTap: (_) {},
        ),
      ),
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('snapping to a card selects it and focuses the map', (t) async {
    final selected = <String>[];
    await t.pumpWidget(
      app(
        NearbyCarousel(
          places: many(6),
          onTap: (_) {},
          onSelected: (p) => selected.add(p.branchId),
        ),
      ),
    );

    await t.drag(find.byType(ListView), const Offset(-300, 0));
    await t.pumpAndSettle();

    expect(selected, ['b2']);
    final screen = t.view.physicalSize.width / t.view.devicePixelRatio;
    final card = t.getCenter(find.byKey(const ValueKey('nearby-card-b2')));
    expect(card.dx, closeTo(screen / 2, 1));
  });

  testWidgets('an external selection scrolls the carousel to that card', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        NearbyCarousel(
          places: many(8),
          selectedBranchId: 'b8',
          onTap: (_) {},
          onSelected: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Kedai 8'), findsOneWidget);
    final screen = t.view.physicalSize.width / t.view.devicePixelRatio;
    final card = t.getCenter(find.byKey(const ValueKey('nearby-card-b8')));
    expect(card.dx, closeTo(screen / 2, 1));
  });
}
