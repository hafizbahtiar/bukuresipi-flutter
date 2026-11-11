import 'dart:convert';

import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipt_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../places/places_fixtures.dart';
import '../receipts_fixtures.dart';

void main() {
  Future<void> pump(
    WidgetTester t,
    FakeReceipts repo, {
    Future<void> Function(String text, Rect? origin)? share,
  }) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: repo),
          ChangeNotifierProvider(create: (_) => PlacesController(FakePlaces())),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: ReceiptPage(
            key: UniqueKey(),
            id: 'r-1',
            poll: const Duration(milliseconds: 10),
            share: share,
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('waits while reading, then the user checks the total and saves', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'reading'),
        receipt(gaps: ['totals_mismatch']),
      ];
    await pump(t, repo);
    expect(find.text('Reading the receipt…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 20));
    await t.pump();
    // The read is shown for checking; the unsure total is marked.
    expect(find.text('Port Lepak Sentul'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-totals_mismatch')), findsOneWidget);
    expect(find.widgetWithText(TextField, '41.15'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('receipt-total')), '40.50');
    await t.tap(find.text('Save'));
    await t.pump();
    expect(repo.confirmed.single.totalSen, 4050);
    expect(repo.confirmed.single.branchId, isNull); // the read's own place
    expect(
      find.text('Saved. The photo is deleted; the numbers stay.'),
      findsOneWidget,
    );
    // No items or charges read: how to add them.
    expect(find.byKey(const ValueKey('receipt-rescan-hint')), findsOneWidget);
  });

  testWidgets('reading with the photo shows it being scanned', (t) async {
    // A 1x1 PNG.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    final repo = FakeReceipts()
      ..photo = png
      ..answers = [receipt(status: 'reading'), receipt()];
    await pump(t, repo);
    await t.pump();
    expect(find.byKey(const ValueKey('receipt-scan')), findsOneWidget);
    expect(find.text('Reading the receipt…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 20));
    await t.pump();
    expect(find.byKey(const ValueKey('receipt-scan')), findsNothing);
    expect(find.text('Port Lepak Sentul'), findsOneWidget);
  });

  testWidgets('the printed lines show while checking and after saving', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(
          items: [
            (
              name: 'Nasi Lemak Ayam',
              quantity: 2,
              amountSen: 2580,
              kcal: null,
              kcalSource: null,
              eaten: 0,
            ),
            (
              name: 'Teh Ais',
              quantity: null,
              amountSen: 350,
              kcal: null,
              kcalSource: null,
              eaten: 0,
            ),
            (
              name: 'Diskaun',
              quantity: 1,
              amountSen: -200,
              kcal: null,
              kcalSource: null,
              eaten: 0,
            ),
          ],
          charges: [
            (kind: 'subtotal', name: null, amountSen: 2730),
            (kind: 'service', name: null, amountSen: 273),
            (kind: 'tax', name: null, amountSen: 164),
            (kind: 'other', name: 'Takeaway Charge', amountSen: 100),
            (kind: 'rounding', name: null, amountSen: -2),
          ],
        ),
      ];
    await pump(t, repo);
    await t.pump();
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('2 ×'), findsOneWidget);
    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
    expect(find.text('RM 25.80'), findsOneWidget);
    expect(find.text('-RM 2.00'), findsOneWidget);
    for (final s in [
      'Subtotal',
      'Service charge',
      'SST',
      'Takeaway Charge',
      'Rounding',
      '-RM 0.02',
    ]) {
      expect(find.text(s), findsOneWidget);
    }
    final save = find.text('Save');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pump();
    expect(find.byKey(const ValueKey('receipt-items')), findsOneWidget);
    expect(find.text('Teh Ais'), findsOneWidget);
  });

  testWidgets(
    'a rescan of a saved receipt: Save offers Update, which opens the saved one',
    (t) async {
      final repo = FakeReceipts()..duplicateOf = 'r-0';
      final router = GoRouter(
        initialLocation: '/receipts/r-1',
        routes: [
          GoRoute(
            path: '/receipts/:id',
            builder: (_, s) => ReceiptPage(
              id: s.pathParameters['id']!,
              poll: const Duration(milliseconds: 10),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ReceiptsRepository>.value(value: repo),
            ChangeNotifierProvider(
              create: (_) => PlacesController(FakePlaces()),
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
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Already saved'), findsOneWidget);
      expect(repo.confirmed, isEmpty);
      await t.tap(find.text('Update'));
      await t.pumpAndSettle();
      expect(repo.confirmed.single.id, 'r-1');
      expect(find.text('Receipt updated'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/receipts/r-0',
      );
    },
  );

  testWidgets('no place found: Save waits until the user picks one', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(place: null, gaps: ['shop']),
      ];
    await pump(t, repo);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(t.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text('Choose a place from your book'), findsOneWidget);
  });

  testWidgets('a bad amount says so and blocks Save', (t) async {
    final repo = FakeReceipts();
    await pump(t, repo);
    await t.enterText(find.byKey(const ValueKey('receipt-total')), '4x');
    await t.pump();
    expect(find.text('Write an amount, like 41.15'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('an unreadable receipt says how to retake it', (t) async {
    await pump(t, FakeReceipts()..answers = [receipt(status: 'failed')]);
    expect(find.textContaining("couldn't read this receipt"), findsOneWidget);
  });

  ReceiptItem line(double? quantity, {int? kcal, double eaten = 0}) => (
    name: 'Nasi Lemak',
    quantity: quantity,
    amountSen: 800,
    kcal: kcal,
    kcalSource: kcal == null ? null : 'ai',
    eaten: eaten,
  );

  testWidgets('ticking a line sends it and shows what was eaten', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'saved', items: [line(null, kcal: 640)]),
        receipt(
          status: 'saved',
          items: [line(null, kcal: 640, eaten: 1)],
          eatenKcal: 640,
          hasEstimate: true,
        ),
      ];
    await pump(t, repo);
    expect(find.text('640 kcal · AI estimate'), findsOneWidget);
    expect(
      find.text('Tick what you ate to count its calories.'),
      findsOneWidget,
    );
    await t.ensureVisible(find.byKey(const ValueKey('eaten-0')));
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(repo.eaten.single, (id: 'r-1', position: 0, eaten: 1.0));
    expect(find.text('You ate: 640 kcal'), findsOneWidget);
    expect(find.text('AI estimate'), findsOneWidget); // the chip
  });

  testWidgets('a line of 3 counts up to 3, no further', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'saved', items: [line(3, eaten: 3)]),
      ];
    await pump(t, repo);
    await t.ensureVisible(find.byKey(const ValueKey('eaten-0')));
    expect(
      t
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    await t.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await t.pump();
    expect(repo.eaten.single.eaten, 2);
  });

  testWidgets('a part-eaten line of 3: its checkbox ticks all 3', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'saved', items: [line(3, eaten: 1)]),
      ];
    await pump(t, repo);
    await t.ensureVisible(find.byKey(const ValueKey('eaten-0')));
    expect(t.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(repo.eaten.single.eaten, 3);
  });

  testWidgets('counting calories polls until the server is done', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'saved', items: [line(1)], caloriesPending: true),
        receipt(status: 'saved', items: [line(1, kcal: 200)]),
      ];
    await pump(t, repo);
    expect(find.text('Counting calories…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 20));
    await t.pump();
    expect(find.text('Counting calories…'), findsNothing);
    expect(find.text('200 kcal · AI estimate'), findsOneWidget);
  });

  testWidgets('a receipt that is not from a restaurant says so', (t) async {
    final repo = FakeReceipts()
      ..answers = [receipt(status: 'failed', reason: 'not_restaurant')];
    await pump(t, repo);
    expect(find.textContaining('Not a restaurant receipt'), findsOneWidget);
  });

  testWidgets(
    'a read receipt has Receipt | Split bill; a reading one does not',
    (t) async {
      await pump(t, FakeReceipts()..answers = [receipt(status: 'saved')]);
      expect(find.text('Split bill'), findsOneWidget);
      await pump(t, FakeReceipts()..answers = [receipt(status: 'reading')]);
      expect(find.text('Split bill'), findsNothing);
      await pump(t, FakeReceipts()..answers = [receipt(status: 'failed')]);
      expect(find.text('Split bill'), findsNothing);
    },
  );

  testWidgets(
    'split: Me first, add Ali, assign a line and share the exact text',
    (t) async {
      final repo = FakeReceipts()
        ..answers = [
          receipt(
            status: 'saved',
            items: [
              (
                name: 'Nasi Lemak',
                quantity: 1,
                amountSen: 1840,
                kcal: null,
                kcalSource: null,
                eaten: 1,
              ),
              (
                name: 'Teh Ais',
                quantity: 1,
                amountSen: 2275,
                kcal: null,
                kcalSource: null,
                eaten: 1,
              ),
            ],
          ),
        ]
        ..splitAnswer = const ReceiptSplit(
          people: [],
          portions: [],
          shares: [
            (person: 0, amountSen: 1840, lines: ['Nasi Lemak']),
            (person: 1, amountSen: 2275, lines: ['Teh Ais']),
          ],
          totalSen: 4115,
        );
      final shared = <String>[];
      await pump(t, repo, share: (text, _) async => shared.add(text));
      await t.tap(find.text('Split bill'));
      await t.pumpAndSettle();
      // Opened for the first time: a draft with Me who pays it all; nothing saved (the calorie ticks stay).
      expect(repo.savedSplits, isEmpty);
      expect(find.text('RM 41.15'), findsWidgets);

      await t.tap(find.byKey(const ValueKey('split-add-person')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('split-name')), 'Ali');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(repo.savedSplits.last.people.map((p) => p.name), ['Me', 'Ali']);

      // One serving: a checkbox; Ali takes it.
      await t.tap(find.byKey(const ValueKey('split-line-0')));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('portion-1')),
          matching: find.byType(Checkbox),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('portion-done')));
      await t.pumpAndSettle();
      expect(repo.savedSplits.last.portions, [
        (position: 0, person: 1, quantity: 1.0),
      ]);
      expect(find.text('RM 22.75'), findsOneWidget);

      final shareButton = find.byKey(const ValueKey('split-share-button'));
      await t.scrollUntilVisible(shareButton, 200);
      await t.pumpAndSettle();
      await t.tap(shareButton);
      await t.pumpAndSettle();
      expect(shared.single, 'Me RM 18.40: Nasi Lemak\nAli RM 22.75: Teh Ais');
    },
  );

  testWidgets('split: the paid tick is saved per person', (t) async {
    final repo = FakeReceipts()
      ..answers = [receipt(status: 'saved', hasSplit: true)]
      ..splitAnswer = const ReceiptSplit(
        people: [(name: 'Me', paid: false), (name: 'Ali', paid: false)],
        portions: [],
        shares: [
          (person: 0, amountSen: 2058, lines: []),
          (person: 1, amountSen: 2057, lines: []),
        ],
        totalSen: 4115,
      );
    await pump(t, repo);
    await t.tap(find.text('Split bill'));
    await t.pumpAndSettle();
    final paid = find.descendant(
      of: find.byKey(const ValueKey('split-share-1')),
      matching: find.byType(Checkbox),
    );
    await t.scrollUntilVisible(paid, 200);
    await t.pumpAndSettle();
    await t.tap(paid);
    await t.pumpAndSettle();
    expect(repo.savedSplits.single.people[1].paid, isTrue);
  });

  testWidgets('split: stopping removes it and returns to the receipt', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..answers = [receipt(status: 'saved', hasSplit: true)]
      ..splitAnswer = const ReceiptSplit(
        people: [(name: 'Me', paid: false)],
        portions: [],
        shares: [(person: 0, amountSen: 4115, lines: [])],
        totalSen: 4115,
      );
    await pump(t, repo);
    await t.tap(find.text('Split bill'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const ValueKey('split-stop')), 200);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('split-stop')));
    await t.pumpAndSettle();
    await t.tap(find.text('Stop splitting').last);
    await t.pumpAndSettle();
    expect(repo.cleared, ['r-1']);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a split hides the manual calorie ticks', (t) async {
    final repo = FakeReceipts()
      ..answers = [
        receipt(status: 'saved', hasSplit: true, items: [line(1, kcal: 640)]),
      ];
    await pump(t, repo);
    expect(find.byKey(const ValueKey('eaten-0')), findsNothing);
    expect(
      find.text('Calories follow what is assigned to Me.'),
      findsOneWidget,
    );
  });
}
