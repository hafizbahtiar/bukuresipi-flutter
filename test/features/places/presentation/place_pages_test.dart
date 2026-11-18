import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/branch_edit_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/branch_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/place_detail_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/merge_sheet.dart';
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
    t.getBottomLeft(find.byKey(const ValueKey('pin-source-grab'))).dy;

/// Opens the first branch's actions: its ⋮ button, or a long press on the tile.
Future<void> branchMenu(WidgetTester t, {bool longPress = false}) async {
  final tile = find.byKey(const ValueKey('branch-b-1'));
  await t.ensureVisible(tile);
  if (longPress) {
    await t.longPress(tile);
  } else {
    await t.tap(find.descendant(of: tile, matching: find.byTooltip('More')));
  }
  await t.pumpAndSettle();
}

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
    // The post says halal (the fixture's quote): tagged as such, never as certified.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('place-halal-tag-a')),
        matching: find.text('Says halal'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'the book tags a place with a valid JAKIM outlet; no claim, no tag',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(
            id: 'a',
            halal: null,
            cert: HalalCert(
              premise: 'X',
              expiresOn: DateTime(2099),
              url: 'https://www.halal.gov.my/x',
              checkedAt: DateTime(2026, 11, 17),
            ),
          ),
          place(id: 'b', name: 'Kedai B', halal: null),
        ];
      await pump(t, const PlacesListPage());
      expect(find.text('JAKIM halal'), findsOneWidget);
      expect(find.byKey(const ValueKey('place-halal-tag-b')), findsNothing);
    },
  );

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

  testWidgets('the book has no FAB; Merge is the owner\'s only', (t) async {
    repo = FakePlaces()..places = [place(id: 'a', name: 'Kedai A')];
    await pump(t, const PlacesListPage());
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('book-merge')), findsNothing);
  });

  testWidgets(
    'the owner merges two places: recipes greyed out, the name the two share suggested',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(id: 'a', name: 'Samurai Yakiniku Bangi'),
          place(id: 'b', name: 'Samurai Yakiniku Setapak'),
        ];
      await pump(t, const PlacesListPage(), role: 'owner');
      fakeRecipes.recipes = [recipe(id: 'r1', name: 'Ayam Masak Merah')];
      await t.fling(
        find.text('Samurai Yakiniku Bangi'),
        const Offset(0, 400),
        1000,
      );
      await t.pumpAndSettle();
      expect(find.text('Ayam Masak Merah'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('book-merge')));
      await t.pumpAndSettle();
      final next = find.byKey(const ValueKey('merge-next'));
      expect(t.widget<FilledButton>(next).onPressed, isNull);
      expect(
        find.text('Tap 2 or more places that are the same company.'),
        findsOneWidget,
      );
      // A recipe can't be picked.
      await t.tap(find.text('Ayam Masak Merah'), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('merge-r-a')));
      await t.pump();
      expect(t.widget<FilledButton>(next).onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('merge-r-b')));
      await t.pump();
      expect(find.text('2 picked'), findsOneWidget);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('merge-name')))
            .controller!
            .text,
        'Samurai Yakiniku',
      );
      await t.tap(find.byKey(const ValueKey('merge-confirm')));
      await t.pumpAndSettle();
      expect(repo.merges.single.$1, ['r-b']);
      expect(repo.merges.single.$2, 'r-a');
      expect(repo.merges.single.$3, 'Samurai Yakiniku');
      expect(find.text('Merged'), findsOneWidget);
      expect(find.byKey(const ValueKey('merge-next')), findsNothing);
    },
  );

  testWidgets(
    'back leaves merge mode, not the page; a picked place is marked selected',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(id: 'a', name: 'Samurai Yakiniku Bangi'),
          place(id: 'b', name: 'Samurai Yakiniku Setapak'),
        ];
      await pump(t, const PlacesListPage(), role: 'owner');
      await t.tap(find.byKey(const ValueKey('book-merge')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('merge-r-a')));
      await t.pump();
      expect(
        t
            .getSemantics(find.byKey(const ValueKey('merge-r-a')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('merge-next')), findsNothing);
      expect(find.byKey(const ValueKey('book-merge')), findsOneWidget);
    },
  );

  test('sharedStart: the words every name starts with', () {
    expect(
      sharedStart(['Samurai Yakiniku Bangi', 'samurai yakiniku Setapak']),
      'Samurai Yakiniku',
    );
    expect(sharedStart(['Kedai A', 'Warung B']), '');
    expect(sharedStart(['Flow', 'Flow Bangi']), 'Flow');
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
      await tapKey(t, 'place-tab-halal');
      expect(find.text('What the post says about halal'), findsOneWidget);
      expect(find.textContaining('Halal ya'), findsOneWidget);
      expect(find.text('Open the post'), findsOneWidget);
      expect(find.textContaining('not a halal certificate'), findsOneWidget);
      // "Halal" is only the tab's name, never a badge on the place.
      expect(find.text('Halal'), findsOneWidget);
      expect(
        find.text(
          'Bukuresipi does not certify halal. JAKIM certifies each outlet on its own and certificates change: check the certificate displayed at the premises.',
        ),
        findsOneWidget,
      );
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
      await tapKey(t, 'more-menu');
      expect(find.text('Open your post'), findsOneWidget);
      await closeMenu(t);
      await pump(t, const PlaceDetailPage(id: 'b'));
      await tapKey(t, 'more-menu');
      expect(find.text('Open your post'), findsNothing);
    },
  );

  testWidgets(
    'a JAKIM certificate shows on its branch with dates and JAKIM\'s link; expired stays, marked',
    (t) async {
      HalalCert cert(DateTime expires) => HalalCert(
        premise: 'NASI KANDAR PELITA - JALAN AMPANG',
        expiresOn: expires,
        url: 'https://www.halal.gov.my/x',
        checkedAt: DateTime(2026, 11, 17),
      );
      repo = FakePlaces()
        ..places = [
          place(id: 'a', halal: null, cert: cert(DateTime(2099, 1, 31))),
          place(id: 'b', halal: null, cert: cert(DateTime(2020, 1, 31))),
        ];
      await pump(t, const PlaceDetailPage(id: 'a'));
      // Under the name: a valid certificate is a JAKIM tag, in place of "No halal claim".
      expect(find.text('JAKIM halal · 1 outlet'), findsOneWidget);
      expect(find.text('No halal claim found'), findsNothing);
      await tapKey(t, 'place-tab-halal');
      expect(find.text('JAKIM halal certificate'), findsOneWidget);
      expect(find.text('NASI KANDAR PELITA - JALAN AMPANG'), findsOneWidget);
      expect(find.textContaining('Valid until Jan 31, 2099'), findsOneWidget);
      expect(find.text('Check on JAKIM'), findsOneWidget);
      expect(find.text('What the post says about halal'), findsNothing);
      await pump(t, const PlaceDetailPage(id: 'b'));
      expect(
        find.byKey(const ValueKey('place-jakim-tag')),
        findsNothing,
      ); // expired = no tag
      await tapKey(t, 'place-tab-halal');
      expect(find.textContaining('Expired Jan 31, 2020'), findsOneWidget);
    },
  );

  testWidgets(
    'the brand is on JAKIM but this outlet is not: said as not confirmed, with JAKIM\'s list; no check for users',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(
            id: 'a',
            halal: null,
            brand: (outlets: 22, url: 'https://www.halal.gov.my/brand'),
          ),
        ];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await tapKey(t, 'place-tab-halal');
      expect(
        find.text('This brand has JAKIM-certified outlets'),
        findsOneWidget,
      );
      expect(
        find.text('JAKIM lists 22 premises under this name.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Nasi Kandar Pelita Ampang: this outlet is not confirmed in JAKIM\'s directory.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('certifies each outlet separately'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('jakim-check-place')), findsNothing);
    },
  );

  testWidgets(
    'the owner works JAKIM from Edit place (the brand\'s outlets: pair, add as branch, own words) and Edit branch (Check)',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a', halal: null)];
      repo.outlets = (
        status: 'ok',
        url: 'https://www.halal.gov.my/x',
        rows: [
          (
            row: (
              premise: 'NASI KANDAR PELITA - JALAN AMPANG',
              company: null,
              address: '149 JALAN AMPANG, 50450',
              expiresOn: DateTime(2027, 1, 31),
            ),
            branchId: null,
            nearBranchId: 'b-1',
          ),
          (
            row: (
              premise: 'NASI KANDAR PELITA - BANGSAR',
              company: null,
              address: '1 JALAN TELAWI, 59100',
              expiresOn: DateTime(2027, 1, 31),
            ),
            branchId: null,
            nearBranchId: null,
          ),
        ],
        more: false,
      );
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      // The place page only shows: the owner's tools are on the edit pages.
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await tapKey(t, 'place-tab-halal');
      expect(find.byKey(const ValueKey('halal-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('jakim-outlet-0')), findsNothing);
      // Edit place > Halal: the brand's outlets, listed on open.
      await tapKey(t, 'more-menu');
      await t.tap(find.text('Edit place'));
      await t.pumpAndSettle();
      // Its cover on top of Details, with Change (the place page has no owner tools).
      expect(find.byKey(const ValueKey('place-cover-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('place-cover-change')), findsOneWidget);
      // JAKIM is asked only once the Halal tab opens (not on every Edit place).
      expect(repo.halalChecks, isEmpty);
      await tapKey(t, 'place-edit-tab-halal');
      expect(repo.halalChecks, ['place:r-a']);
      expect(find.text('2 outlets on JAKIM'), findsOneWidget);
      expect(
        find.text('Same postcode as Nasi Kandar Pelita Ampang'),
        findsOneWidget,
      );
      // The first is probably our branch (same postcode): one tap pairs it.
      await tapKey(t, 'jakim-pair-near-0');
      expect(repo.halalCerts, [
        (
          'b-1',
          'NASI KANDAR PELITA - JALAN AMPANG',
          'https://www.halal.gov.my/x',
        ),
      ]);
      // The second is not one of ours yet: added as a branch with its certificate.
      await tapKey(t, 'jakim-add-1');
      // Pair and add follow the book: no new JAKIM search.
      expect(repo.halalChecks, ['place:r-a']);
      expect(repo.siblings, [
        ('b-1', '1 JALAN TELAWI, 59100', null, 'NASI KANDAR PELITA - BANGSAR'),
      ]);
      // The field starts with the place's name (what the list searched).
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('place-halal-query')))
            .controller!
            .text,
        isNotEmpty,
      );
      // Own words: the company name.
      await t.enterText(
        find.byKey(const ValueKey('place-halal-query')),
        'Pelita Sdn Bhd',
      );
      await tapKey(t, 'place-halal-search');
      expect(repo.halalChecks, contains('place:r-a:Pelita Sdn Bhd'));
      await t.pageBack();
      await t.pumpAndSettle();
      // Edit branch > Halal: one button; not found = pair it from Edit place.
      await tapKey(t, 'place-tab-branches');
      await branchMenu(t);
      await t.tap(find.text('Edit branch'));
      await t.pumpAndSettle();
      await tapKey(t, 'branch-tab-halal');
      expect(find.byKey(const ValueKey('branch-halal-query')), findsNothing);
      await tapKey(t, 'branch-halal-check');
      expect(repo.halalChecks.last, 'branch:b-1');
      expect(
        find.textContaining('Pair it from Edit place > Halal'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Edit branch > Halal: the company behind the certificate, and Get company info again',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      repo = FakePlaces()
        ..places = [
          place(
            id: 'a',
            cert: HalalCert(
              premise: 'NASI KANDAR PELITA - JALAN AMPANG',
              expiresOn: DateTime(2028, 4, 15),
              url: 'https://www.halal.gov.my/x',
              checkedAt: DateTime.utc(2026, 11, 17),
            ),
          ),
        ]
        ..company = const BranchCompany(
          premise: 'NASI KANDAR PELITA - JALAN AMPANG',
          brand: 'Pelita',
          premiseAddress: '149 Jalan Ampang, 50450, Kuala Lumpur',
          company: HalalCompany(code: 'COMP-1', name: 'PELITA SDN BHD'),
        )
        ..refreshed = BranchCompany(
          status: 'ok',
          brand: 'Pelita',
          company: HalalCompany(
            code: 'COMP-1',
            name: 'PELITA SDN BHD',
            phone: '60321620000',
            website: 'www.pelita.com.my',
            readAt: DateTime.utc(2026, 11, 19),
          ),
        );
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await branchMenu(t);
      await t.tap(find.text('Edit branch'));
      await t.pumpAndSettle();
      await tapKey(t, 'branch-tab-halal');
      expect(repo.companyCalls, ['get:b-1']);
      expect(find.text('PELITA SDN BHD'), findsOneWidget);
      expect(find.text('Company page not read yet.'), findsOneWidget);
      expect(
        find.text('149 Jalan Ampang, 50450, Kuala Lumpur'),
        findsOneWidget,
      );
      // The certificate card: status at a glance, then JAKIM's rows and how it was linked.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('branch-cert-status')),
          matching: find.text('Valid'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cert-brand')),
          matching: find.text('Pelita'),
        ),
        findsOneWidget,
      );
      expect(find.text('Apr 15, 2028'), findsOneWidget);
      expect(find.text('Matched by the JAKIM check'), findsOneWidget);

      await tapKey(t, 'branch-company-refresh');
      expect(repo.companyCalls, ['get:b-1', 'refresh:b-1']);
      expect(find.text('60321620000'), findsOneWidget);
      expect(find.text('www.pelita.com.my'), findsOneWidget);
      expect(find.text('Read from JAKIM on Nov 19, 2026'), findsOneWidget);
      expect(find.text('Company info updated.'), findsOneWidget);
    },
  );

  testWidgets('a branch with no certificate shows no company card', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    await tapKey(t, 'branch-tab-halal');
    expect(find.byKey(const ValueKey('branch-company')), findsNothing);
    expect(repo.companyCalls, isEmpty);
  });

  testWidgets(
    'Book: one filter row; Been there / Want to try with counts, tap again for all',
    (t) async {
      repo = FakePlaces()
        ..places = [
          place(id: 'a', name: 'Kedai Satu', visited: true),
          place(id: 'b', name: 'Kedai Dua'),
          place(id: 'c', name: 'Kedai Tiga'),
        ];
      await pump(t, const PlacesListPage());
      expect(
        find.byKey(const ValueKey('book-filter-mine')),
        findsNothing,
      ); // not in a family
      expect(find.text('Been there · 1'), findsOneWidget);
      expect(find.text('Want to try · 2'), findsOneWidget);
      await tapKey(t, 'book-visit-toTry');
      expect(find.text('Kedai Satu'), findsNothing);
      expect(find.text('Kedai Dua'), findsOneWidget);
      await tapKey(t, 'book-visit-been');
      expect(find.text('Kedai Satu'), findsOneWidget);
      expect(find.text('Kedai Dua'), findsNothing);
      await tapKey(t, 'book-visit-been'); // off again: everything
      expect(find.text('Kedai Dua'), findsOneWidget);
      expect(find.text('Kedai Satu'), findsOneWidget);
    },
  );

  testWidgets('Book: no receipts and no family, no filter row', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlacesListPage());
    expect(find.byKey(const ValueKey('book-filters')), findsNothing);
  });

  testWidgets(
    'Edit branch: tabs swipe; the search box starts with each map\'s own words, typed words stay',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      repo = FakePlaces()
        ..places = [place(id: 'a')]
        ..pinDefaults = {
          'osm': 'Nasi Kandar Pelita, Ampang',
          'here': 'Nasi Kandar Pelita, Ampang',
          'grab': 'Nasi Kandar Pelita',
          'jakim': 'nasi kandar pelita',
        };
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await branchMenu(t);
      await t.tap(find.text('Edit branch'));
      await t.pumpAndSettle();
      // Swipe left from Branch: Find.
      Future<void> swipe() => t.flingFrom(
        t.getCenter(find.byType(PageView)),
        const Offset(-600, 0),
        1500,
      );
      await swipe();
      await t.pumpAndSettle();
      String box() => t
          .widget<TextField>(find.byKey(const ValueKey('pin-search-query')))
          .controller!
          .text;
      expect(box(), 'Nasi Kandar Pelita, Ampang'); // HERE, the first map
      await tapKey(t, 'pin-source-grab');
      expect(box(), 'Nasi Kandar Pelita');
      await t.enterText(
        find.byKey(const ValueKey('pin-search-query')),
        'Pelita Ampang Point',
      );
      await tapKey(t, 'pin-source-osm');
      expect(box(), 'Pelita Ampang Point'); // the owner's words stay
      expect(repo.pinSearches, isEmpty); // nothing asked yet
      // Swipe on: Halal.
      await swipe();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('branch-halal-check')), findsOneWidget);
    },
  );

  testWidgets(
    'Edit place > Halal: the companies behind its certified outlets, and Get company info again for them all',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      const kopi = HalalCompany(code: 'COMP-1', name: 'KOPITIAM SDN BHD');
      repo = FakePlaces()
        ..places = [place(id: 'a')]
        ..placeCompaniesList = (
          status: null,
          left: 0,
          branches: const [
            (
              branchId: 'b-1',
              label: 'Pelita Ampang',
              info: BranchCompany(premise: 'P1', company: kopi),
            ),
            (
              branchId: 'b-2',
              label: 'Pelita Bangsar',
              info: BranchCompany(premise: 'P2', company: kopi),
            ),
            (
              branchId: 'b-3',
              label: 'Pelita Cheras',
              info: BranchCompany(premise: 'P3'),
            ),
          ],
        )
        ..placeCompaniesRefreshed = (
          status: 'ok',
          left: 2,
          branches: const [
            (
              branchId: 'b-1',
              label: 'Pelita Ampang',
              info: BranchCompany(
                premise: 'P1',
                company: HalalCompany(
                  code: 'COMP-1',
                  name: 'KOPITIAM SDN BHD',
                  phone: '60321620000',
                ),
              ),
            ),
          ],
        );
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await tapKey(t, 'more-menu');
      await t.tap(find.text('Edit place'));
      await t.pumpAndSettle();
      expect(repo.companyCalls, isEmpty); // asked only when Halal opens
      await tapKey(t, 'place-edit-tab-halal');
      expect(repo.companyCalls, ['get:r-a']);
      // One company, both its outlets under it; the outlet with no company listed apart.
      expect(find.text('KOPITIAM SDN BHD'), findsOneWidget);
      expect(
        find.text('Outlets: Pelita Ampang, Pelita Bangsar'),
        findsOneWidget,
      );
      expect(find.textContaining('no company yet'), findsOneWidget);
      expect(find.textContaining('Pelita Cheras'), findsOneWidget);
      final go = find.byKey(const ValueKey('place-companies-refresh'));
      await t.ensureVisible(go);
      await t.tap(go);
      await t.pumpAndSettle();
      expect(repo.companyCalls.last, 'refresh:r-a');
      expect(find.text('60321620000'), findsOneWidget);
      expect(
        find.text('2 more companies not read yet: press again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no claim, no halal section', (t) async {
    repo = FakePlaces()..places = [place(id: 'a', halal: null)];
    await pump(t, const PlaceDetailPage(id: 'a'));
    expect(find.text('What the post says about halal'), findsNothing);
  });

  testWidgets(
    'the owner\'s delete dialogs say who they reach: own book, or every user',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await tapKey(t, 'more-menu');
      await t.tap(find.text('Remove from my book'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-scope-mine')), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repo.removed, isEmpty);
    },
  );

  testWidgets(
    'a branch and the edit pages open with the standard transition, not the flip',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      final branch = repo.places.single.branches.first;
      await t.tap(find.byKey(ValueKey('branch-${branch.id}')));
      await t.pumpAndSettle();
      expect(
        ModalRoute.of(t.element(find.byType(BranchPage))),
        isNot(isA<MaterialPageRoute<void>>()),
      );
      await tapKey(t, 'branch-edit');
      expect(
        ModalRoute.of(t.element(find.byType(BranchEditPage))),
        isA<PageRouteBuilder<bool>>(),
      );
    },
  );

  testWidgets('remove asks first, then takes the place off the book', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    // In the app bar's ⋮ menu: always in reach, no scrolling.
    await tapKey(t, 'more-menu');
    await t.tap(find.text('Remove from my book'));
    await t.pumpAndSettle();
    expect(repo.removed, isEmpty);
    // A user has only their own book: no scope card.
    expect(find.byKey(const ValueKey('delete-scope-mine')), findsNothing);
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
    await branchMenu(t);
    expect(find.text('Delete branch'), findsNothing);
    await t.tapAt(const Offset(10, 10)); // closes the sheet
    await t.pumpAndSettle();

    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t, longPress: true);
    await t.tap(find.text('Delete branch'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(repo.deletedBranches, ['b-1']);
  });

  testWidgets('the owner edits a branch from the place page', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    // One door: the owner edits for everyone, said by the strip under the bar.
    expect(find.byKey(const ValueKey('owner-strip')), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('branch-label')), 'Kedai Baru');
    await t.enterText(
      find.byKey(const ValueKey('branch-address')),
      'Jalan Baru',
    );
    final save = find.byKey(const ValueKey('branch-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'Kedai Baru');
    expect(repo.branchUpdates.single.address, 'Jalan Baru');
    expect(repo.branchUpdates.single.lat, isNull);
    expect(repo.branchUpdates.single.lng, isNull);
    expect(repo.branchUpdates.single.scope, BranchEditScope.shared);
  });

  testWidgets(
    'Edit place: a picked cover shows as pending; only Save saves it',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      repo = FakePlaces()
        ..places = [place(id: 'a')]
        ..coverIds = ['aa', 'bb'];
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await tapKey(t, 'more-menu');
      await t.tap(find.text('Edit place'));
      await t.pumpAndSettle();
      await tapKey(t, 'place-cover-change');
      await tapKey(t, 'cover-bb');
      expect(repo.coverPicks, isEmpty);
      expect(find.byKey(const ValueKey('place-cover-pending')), findsOneWidget);
      await tapKey(t, 'place-save');
      expect(repo.coverPicks, ['bb']);
    },
  );

  testWidgets('the owner edits the main place: name, category, type, cuisine', (
    t,
  ) async {
    // The cover sits on top of the form: a tall window keeps every field in reach.
    await t.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await tapKey(t, 'more-menu');
    expect(find.text('Edit place'), findsNothing);
    await closeMenu(t);

    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await tapKey(t, 'more-menu');
    await t.tap(find.text('Edit place'));
    await t.pumpAndSettle();
    // A name is required.
    await t.enterText(find.byKey(const ValueKey('place-name')), ' ');
    await t.tap(find.byKey(const ValueKey('place-save')));
    await t.pump();
    expect(find.text("Enter the place's name."), findsOneWidget);
    expect(repo.restaurantUpdates, isEmpty);

    await t.enterText(find.byKey(const ValueKey('place-name')), 'Kedai Baru');
    // Food (the default) offers cuisine and food types.
    expect(find.byKey(const ValueKey('place-cuisine')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('place-subcategory')));
    await t.pumpAndSettle();
    await t.tap(find.text('Mamak'));
    await t.pumpAndSettle();
    expect(find.text('Mamak'), findsOneWidget);
    // A shop: no cuisine, and the food type is cleared.
    await t.tap(find.byKey(const ValueKey('place-category')));
    await t.pumpAndSettle();
    await t.tap(find.text('Shop'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-cuisine')), findsNothing);
    expect(find.text('Mamak'), findsNothing);
    await t.tap(find.byKey(const ValueKey('place-subcategory')));
    await t.pumpAndSettle();
    await t.tap(find.text('Market'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('place-save')));
    await t.pumpAndSettle();
    final saved = repo.restaurantUpdates.single;
    expect(
      (saved.$2, saved.$3, saved.$4, saved.$5),
      ('Kedai Baru', 'shop', 'market', null),
    );
    expect(find.byKey(const ValueKey('place-save')), findsNothing);
  });

  testWidgets(
    'the branch page: a JAKIM tag and its certificate in Halal; none = the brand note, else nothing known',
    (t) async {
      final cert = HalalCert(
        premise: 'NASI KANDAR PELITA - JALAN AMPANG',
        expiresOn: DateTime(2099, 1, 31),
        url: 'https://www.halal.gov.my/x',
        checkedAt: DateTime(2026, 11, 17),
      );
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      Future<void> open(Place p) async {
        repo = FakePlaces()..places = [p];
        await pump(t, PlaceDetailPage(id: p.id));
        await t.tap(find.byKey(const ValueKey('branch-b-1')));
        await t.pumpAndSettle();
      }

      await open(place(id: 'a', halal: null, cert: cert));
      expect(find.byKey(const ValueKey('halal-cert-b-1')), findsOneWidget);
      expect(find.text('JAKIM halal'), findsWidgets); // the tag
      await t.pageBack();
      await t.pumpAndSettle();
      await open(
        place(
          id: 'c',
          halal: null,
          brand: (outlets: 22, url: 'https://www.halal.gov.my/brand'),
        ),
      );
      expect(find.byKey(const ValueKey('halal-brand')), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await open(place(id: 'd', halal: null));
      expect(find.byKey(const ValueKey('branch-halal-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'a branch\'s own photo tops its page; the owner takes one in Edit branch (saved at once)',
    (t) async {
      final p = place(id: 'a');
      repo = FakePlaces()
        ..places = [
          Place(
            id: p.id,
            sourceUrl: p.sourceUrl,
            note: null,
            createdAt: p.createdAt,
            branchId: 'b-1',
            restaurant: p.restaurant,
            branches: [
              Branch(
                id: 'b-1',
                label: 'Pelita Ampang',
                lat: 3.1,
                lng: 101.7,
                pinSource: 'osm',
                cover: 'c1',
              ),
            ],
          ),
        ];
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await t.tap(find.byKey(const ValueKey('branch-b-1')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('branch-photo')), findsOneWidget);
      await tapKey(t, 'branch-edit');
      expect(find.byKey(const ValueKey('branch-cover-field')), findsOneWidget);
      await tapKey(t, 'branch-cover-remove');
      expect(repo.branchCovers, [('b-1', null)]);
    },
  );

  testWidgets('a branch opens in view mode; the pencil switches to edit', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    final tile = find.byKey(const ValueKey('branch-b-1'));
    await t.ensureVisible(tile);
    await t.tap(tile);
    await t.pumpAndSettle();
    // View mode: the facts, read only.
    expect(find.byType(TextField), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('branch-view-address')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('branch-edit')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('branch-address')),
      'Jalan Baru',
    );
    await t.tap(find.byKey(const ValueKey('branch-save')));
    await t.pumpAndSettle();
    expect(repo.branchUpdates.single.address, 'Jalan Baru');
    // Saved: back on the view page.
    expect(find.byKey(const ValueKey('branch-edit')), findsOneWidget);
  });

  testWidgets('town and state are dropdowns from the server list', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
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
    await t.tap(state);
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
    final save = find.byKey(const ValueKey('branch-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(repo.branchUpdates.single.city, 'Kajang');
    expect(repo.branchUpdates.single.state, 'Selangor');
  });

  testWidgets('a user can edit a branch for themselves only', (t) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));

    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    expect(find.text('Only you will see these changes.'), findsOneWidget);
    expect(find.byKey(const ValueKey('owner-strip')), findsNothing);
    expect(find.text('Suggest with AI'), findsNothing);

    await t.enterText(find.byKey(const ValueKey('branch-label')), 'My Kedai');
    final save = find.byKey(const ValueKey('branch-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'My Kedai');
    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
    expect(find.text('Saved for you.'), findsOneWidget);
  });

  testWidgets('the owner has no Only-me switch: their save is for everyone', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    expect(find.byType(SegmentedButton<BranchEditScope>), findsNothing);
    expect(find.byTooltip('Save for everyone'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('branch-label')), 'Shared');
    await tapKey(t, 'branch-save');
    expect(repo.branchUpdates.single.scope, BranchEditScope.shared);
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
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();

    await tapKey(t, 'branch-tab-find');
    final suggest = find.text('Suggest with AI');
    await t.ensureVisible(suggest);
    await t.tap(suggest);
    await t.pumpAndSettle();

    expect(repo.suggested, ['b-1']);
    expect(find.text('AI draft — review before saving'), findsOneWidget);
    expect(find.text('Source: OpenStreetMap'), findsOneWidget);
    expect(
      find.text(
        "Already filled into the Branch tab. Untick any you don't want.",
      ),
      findsOneWidget,
    );
    // The owner leaves the AI's address: the form goes back to the current one; ticked again, the AI's returns.
    final address = find.descendant(
      of: find.byKey(const ValueKey('draft-address')),
      matching: find.byType(Checkbox),
    );
    await t.ensureVisible(address);
    await t.tap(address);
    await t.pumpAndSettle();
    // The form is on the Branch tab (kept, offstage, while Find shows).
    String text(String key) => t
        .widget<TextField>(find.byKey(ValueKey(key), skipOffstage: false))
        .controller!
        .text;
    expect(text('branch-address'), '');
    await t.tap(address);
    await t.pumpAndSettle();
    expect(text('branch-address'), 'AI Address');
    await t.tap(address);
    await t.pumpAndSettle();
    expect(find.text('AI'), findsWidgets);
    expect(
      t
          .widget<TextField>(
            find.byKey(const ValueKey('branch-label'), skipOffstage: false),
          )
          .controller!
          .text,
      'AI Label',
    );
    expect(
      t
          .widget<TextField>(
            find.byKey(const ValueKey('branch-lat'), skipOffstage: false),
          )
          .controller!
          .text,
      '2.991234',
    );

    final save = find.byKey(const ValueKey('branch-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'AI Label');
    expect(repo.branchUpdates.single.lat, 2.991234);
    expect(
      repo.branchUpdates.single.address,
      isNull,
    ); // unticked: kept as it was (none)
    expect(repo.branchUpdates.single.city, 'AI City');
    expect(repo.branchUpdates.single.state, 'Selangor');
    expect(repo.branchUpdates.single.lng, 101.791234);
    expect(repo.branchUpdates.single.scope, BranchEditScope.shared);
  });

  testWidgets(
    'the draft offers web photos and page links; a picked photo becomes the branch photo when it is saved',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      repo.suggestion = const BranchSuggestion(
        draft: BranchDraft(label: 'AI Label'),
        sources: [],
        aiUsed: true,
        changed: true,
        pages: [(url: 'https://www.flow.my/bangi', title: 'FLOW Bangi')],
        photos: ['https://flow.my/a.jpg', 'https://flow.my/b.jpg'],
        placeId: 'r-9',
      );
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await branchMenu(t);
      await t.tap(find.text('Edit branch'));
      await t.pumpAndSettle();
      await tapKey(t, 'branch-tab-find');
      final suggest = find.text('Suggest with AI');
      await t.ensureVisible(suggest);
      await t.tap(suggest);
      await t.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'flow.my'), findsOneWidget);
      final photo = find.byKey(
        const ValueKey('draft-photo-https://flow.my/b.jpg'),
      );
      await t.ensureVisible(photo);
      await t.tap(photo);
      await t.pumpAndSettle();

      final save = find.byKey(const ValueKey('branch-save'));
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(repo.branchUpdates.single.label, 'AI Label');
      // The outlet's own photo; the place's cover is untouched (Edit place may take it from the branch).
      expect(repo.branchCovers, [('b-1', 'https://flow.my/b.jpg')]);
      expect(repo.coverUrls, isEmpty);
    },
  );

  testWidgets(
    'the draft\'s JAKIM rows show in the Halal tab with the AI pick marked; Save stores one at once',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      repo.suggestion = BranchSuggestion(
        draft: const BranchDraft(label: 'AI Label'),
        sources: const ['jakim'],
        aiUsed: true,
        changed: true,
        jakim: (
          url: 'https://www.halal.gov.my/index.php?cari=pelita',
          rows: [
            (
              premise: 'NASI KANDAR PELITA - JALAN AMPANG',
              company: 'PELITA SDN BHD',
              address: '149 JALAN AMPANG, 50450, Kuala Lumpur',
              expiresOn: DateTime(2026, 11, 30),
            ),
            (
              premise: 'NASI KANDAR PELITA - KLCC',
              company: 'PELITA SDN BHD',
              address: 'LOT 1, 50088, Kuala Lumpur',
              expiresOn: DateTime(2027, 1, 31),
            ),
          ],
          pick: 0,
        ),
      );
      await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
      await branchMenu(t);
      await t.tap(find.text('Edit branch'));
      await t.pumpAndSettle();
      await tapKey(t, 'branch-tab-find');
      final suggest = find.text('Suggest with AI');
      await t.ensureVisible(suggest);
      await t.tap(suggest);
      await t.pumpAndSettle();

      // The Find tab only says where they are.
      expect(
        find.text('JAKIM: outlets found. Pick one in the Halal tab.'),
        findsOneWidget,
      );
      await tapKey(t, 'branch-tab-halal');
      expect(find.text('NASI KANDAR PELITA - JALAN AMPANG'), findsOneWidget);
      expect(find.textContaining('valid until Nov 30, 2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('jakim-row-0')),
          matching: find.text('AI pick'),
        ),
        findsOneWidget,
      );
      // The owner disagrees: KLCC instead.
      await t.ensureVisible(find.byKey(const ValueKey('jakim-save-1')));
      await tapKey(t, 'jakim-save-1');
      expect(repo.halalCerts, [
        (
          'b-1',
          'NASI KANDAR PELITA - KLCC',
          'https://www.halal.gov.my/index.php?cari=pelita',
        ),
      ]);
    },
  );

  testWidgets('the owner can type coordinates instead of using the map', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();

    final lat = find.byKey(const ValueKey('branch-lat'));
    final lng = find.byKey(const ValueKey('branch-lng'));
    await t.ensureVisible(lat);
    await t.enterText(lat, '2.991234');
    await t.ensureVisible(lng);
    await t.enterText(lng, '101.791234');
    final save = find.byKey(const ValueKey('branch-save'));
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
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
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
    final save = find.byKey(const ValueKey('branch-save'));
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
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    await tapKey(t, 'branch-tab-find');
    final suggest = find.text('Suggest with AI');
    await t.ensureVisible(suggest);
    await t.tap(suggest);
    await t.pumpAndSettle();

    expect(find.text('Pins found'), findsOneWidget);
    expect(find.textContaining('545 m'), findsOneWidget);
    // The draft always says what JAKIM gave, here nothing (no answer).
    expect(
      find.text(
        'JAKIM did not answer. Try Check JAKIM in the Halal tab later.',
      ),
      findsOneWidget,
    );
    final use = find.descendant(
      of: find.byKey(const ValueKey('pin-grab')),
      matching: find.text('Use'),
    );
    await t.ensureVisible(use);
    await t.tap(use);
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(
            find.byKey(const ValueKey('branch-lat'), skipOffstage: false),
          )
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
          name: null,
        ),
        (
          lat: null,
          lng: null,
          address: 'D-7-G, Bangi Gateway',
          city: 'Bandar Baru Bangi',
          state: 'Selangor',
          source: 'jakim',
          name: 'FLOW SMOKE & BREW - BANGI GATEWAY',
        ),
      ];
    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    await tapKey(t, 'branch-tab-find');
    Future<void> search(String source) async {
      await t.ensureVisible(find.byKey(ValueKey('pin-source-$source')));
      await tapKey(t, 'pin-source-$source');
      final go = find.byKey(const ValueKey('pin-search-go'));
      await t.ensureVisible(go);
      await t.tap(go);
      await t.pumpAndSettle();
    }

    // Picking a map asks nothing (HERE and GrabMaps are metered): it says what the map is, Search asks it.
    await tapKey(t, 'pin-source-here');
    expect(repo.pinSearches, isEmpty);
    expect(find.textContaining('monthly quota'), findsOneWidget);
    await search('osm');
    expect(repo.pinSearches.last.$2, 'osm');
    // Results show in the tab, each with Use and New branch.
    expect(find.text('2 results from OpenStreetMap'), findsOneWidget);
    // JAKIM: the halal-listed outlets, each named as JAKIM lists it.
    await search('jakim');
    expect(repo.pinSearches.last.$2, 'jakim');
    expect(find.text('FLOW SMOKE & BREW - BANGI GATEWAY'), findsOneWidget);
    expect(find.textContaining('No pin: pin it with'), findsOneWidget);
    await search('grab');
    expect(repo.pinSearches.last.$2, 'grab');
    // The first map's default words are not sent to the next: each map gets its own.
    expect(repo.pinSearches.last.$3, isNull);
    expect(spacing(t), greaterThanOrEqualTo(8));

    // Another outlet in the results: added as a new branch, the form untouched.
    final add = find.byKey(const ValueKey('pin-hit-add-0'));
    await t.ensureVisible(add);
    await t.tap(add);
    await t.pumpAndSettle();
    expect(repo.siblings, [
      ('b-1', 'P&C Kitchen, Jalan Ampang, Kuala Lumpur', 3.1591, null),
    ]);
    expect(
      find.text('Branch added. Edit its name on the map if needed.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pin-hit-0')),
        matching: find.text('Added'),
      ),
      findsOneWidget,
    );

    final use = find.byKey(const ValueKey('pin-hit-use-0'));
    await t.ensureVisible(use);
    await t.tap(use);
    await t.pumpAndSettle();
    String field(String key) => t
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key), skipOffstage: false),
            matching: find.byType(TextField, skipOffstage: false),
            matchRoot: true,
          ),
        )
        .controller!
        .text;
    expect(field('branch-lat'), '3.159100');
    expect(field('branch-address'), 'P&C Kitchen, Jalan Ampang, Kuala Lumpur');
    expect(field('branch-city'), 'Kuala Lumpur');
    expect(field('branch-state'), 'Wilayah Persekutuan Kuala Lumpur');
    expect(
      field('pin-search-query'),
      'Shop, Kuala Lumpur',
    ); // what was asked, to change and search again
    // Back on the Branch tab, the location says the pin is new.
    await tapKey(t, 'branch-tab-details');
    expect(find.text('New pin, not saved yet'), findsOneWidget);
  });

  testWidgets('a pinned place has a Map item that opens the map on its pin', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a', lat: 3.15)];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await tapKey(t, 'more-menu');
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets(
    'a report can take the pin from a Google Maps link, sent with the link',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await tapKey(t, 'more-menu');
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
    await branchMenu(t);
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('pin-search-query')), findsNothing);
  });

  testWidgets('the owner can check a restaurant\'s branches; users cannot', (
    t,
  ) async {
    repo = FakePlaces()..places = [place(id: 'a')];
    await pump(t, const PlaceDetailPage(id: 'a'));
    await tapKey(t, 'more-menu');
    expect(find.text('Check branches'), findsNothing);
    await closeMenu(t);

    await pump(t, const PlaceDetailPage(id: 'a'), role: 'owner');
    await tapKey(t, 'more-menu');
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
    'Save note under the note is off until the note changes, then saves it',
    (t) async {
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await tapKey(t, 'place-tab-note');
      final save = find.byKey(const ValueKey('note-save'));
      expect(t.widget<ButtonStyleButton>(save).enabled, isFalse);
      await t.enterText(find.byType(TextField), 'Order the ayam goreng');
      await t.pump();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(repo.notes, {'a': 'Order the ayam goreng'});
    },
  );

  testWidgets(
    'typing a note with the keyboard open: the note shows above the keyboard',
    (t) async {
      t.view.physicalSize = const Size(1080, 1800); // a short phone
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      repo = FakePlaces()..places = [place(id: 'a')];
      await pump(t, const PlaceDetailPage(id: 'a'));
      await tapKey(t, 'place-tab-note');
      await t.showKeyboard(find.byType(TextField));
      t.view.viewInsets = const FakeViewPadding(
        bottom: 900,
      ); // 300 logical px of keyboard
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Sedap, datang lagi');
      await t.pumpAndSettle();
      final field = t.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(1800 / 3 - 300));
      expect(field.top, greaterThanOrEqualTo(0));
    },
  );
}

/// Taps the widget with [key] (a tab, the ⋮ menu) and waits for it to settle.
Future<void> tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await t.pumpAndSettle();
}

/// Closes an open popup menu (a tap outside it).
Future<void> closeMenu(WidgetTester t) async {
  await t.tapAt(const Offset(1, 1));
  await t.pumpAndSettle();
}
