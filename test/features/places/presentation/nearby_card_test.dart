import 'package:bukuresipi_flutter/features/places/domain/market.dart';
import 'package:bukuresipi_flutter/features/places/domain/nearby_branch.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/nearby_card.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';

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

void main() {
  testWidgets('a nearby card shows the place info', (t) async {
    final tapped = <String>[];
    await t.pumpWidget(
      app(
        Column(
          children: [
            for (final p in [
              nearbyBranch(name: 'Kedai Dekat', distanceM: 350),
              nearbyBranch(
                branchId: 'b-2',
                name: 'Kedai Jauh',
                distanceM: 2400,
                cert: HalalCert(
                  premise: 'KEDAI JAUH',
                  expiresOn: DateTime(2099),
                  url: 'https://www.halal.gov.my/x',
                  checkedAt: DateTime(2026, 11, 17),
                ),
              ),
            ])
              SizedBox(
                height: 100,
                child: NearbyCard(
                  place: p,
                  onTap: () => tapped.add(p.branchId),
                ),
              ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Kedai Dekat'), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('Kedai Jauh'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('Melayu'), findsNWidgets(2));
    // An outlet on JAKIM shows that instead of the post's claim.
    expect(find.text('Says halal'), findsOneWidget);
    expect(find.text('JAKIM halal'), findsOneWidget);
    expect(find.text('Kedai Sederhana Bangsar'), findsNWidgets(2));
    expect(
      find.text('Jalan Telawi'),
      findsNothing,
    ); // the branch label says more

    await t.tap(find.text('Kedai Dekat'));
    expect(tapped, ['b-1']);
  });

  testWidgets('a saved card is marked Saved', (t) async {
    await t.pumpWidget(
      app(
        SizedBox(
          height: 100,
          child: NearbyCard(
            place: nearbyBranch(saved: true, savedPlaceId: 'p-1'),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets(
    'no overflow on a 360 dp phone at 1.3x text with long names and stars',
    (t) async {
      t.view.physicalSize = const Size(360, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final long = NearbyBranch(
        branchId: 'b-long',
        placeId: 'r-1',
        name: 'Restoran Nasi Kandar Yang Sangat Panjang Namanya Sekali',
        label: 'Cawangan Taman Melawati Hulu Kelang Selangor Darul Ehsan',
        lat: 3.15,
        lng: 101.71,
        distanceM: 12345,
        saved: true,
        cuisine: 'Masakan Melayu Tradisional Pantai Timur',
        halalClaim: 'says_halal',
        halalQuote: 'Halal',
        rating: const RatingSummary(average: 4.6, count: 128),
      );
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(
            Builder(
              builder: (context) => SizedBox(
                width: 328,
                height: NearbyCard.heightOf(context),
                child: NearbyCard(place: long, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.text('4.6 (128)'), findsOneWidget);
    },
  );

  testWidgets(
    'today on the card: open until, the break, opens later; no hours = no line',
    (t) async {
      const lunch = [
        MarketDay(day: 1, opens: '11:00', closes: '15:00'),
        MarketDay(day: 1, opens: '17:00', closes: '22:00'),
      ];
      Future<void> card(DateTime now, [List<MarketDay> s = lunch]) async {
        await t.pumpWidget(
          app(
            SizedBox(
              height: 100,
              child: NearbyCard(
                place: nearbyBranch(schedule: s),
                now: now,
                onTap: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      // 2026-11-23 is a Monday (Malaysia time).
      await card(DateTime.utc(2026, 11, 23, 12));
      expect(
        find.text('Open now · until 3:00 PM · Kedai Sederhana Bangsar'),
        findsOneWidget,
      );
      await card(DateTime.utc(2026, 11, 23, 16));
      expect(
        find.text('Break until 5:00 PM · Kedai Sederhana Bangsar'),
        findsOneWidget,
      );
      await card(DateTime.utc(2026, 11, 23, 9));
      expect(
        find.text('Opens 11:00 AM · Kedai Sederhana Bangsar'),
        findsOneWidget,
      );
      await card(DateTime.utc(2026, 11, 23, 12), const []);
      expect(find.text('Kedai Sederhana Bangsar'), findsOneWidget);
    },
  );
}
