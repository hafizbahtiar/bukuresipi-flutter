import 'dart:convert';

import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipt_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../places/places_fixtures.dart';
import '../receipts_fixtures.dart';

void main() {
  Future<void> pump(WidgetTester t, FakeReceipts repo) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: repo),
          ChangeNotifierProvider(create: (_) => PlacesController(FakePlaces())),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: ReceiptPage(id: 'r-1', poll: Duration(milliseconds: 10)),
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
            (name: 'Nasi Lemak Ayam', quantity: 2, amountSen: 2580),
            (name: 'Teh Ais', quantity: null, amountSen: 350),
            (name: 'Diskaun', quantity: 1, amountSen: -200),
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
}
