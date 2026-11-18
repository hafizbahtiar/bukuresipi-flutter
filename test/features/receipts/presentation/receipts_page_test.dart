import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipts_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../receipts_fixtures.dart';

void main() {
  Future<void> pump(WidgetTester t, FakeReceipts repo) async {
    await t.pumpWidget(
      Provider<ReceiptsRepository>.value(
        value: repo,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CustomScrollView(slivers: [ReceiptsSection()])),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Load more brings the next page and goes away on the last', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..pageSize = 2
      ..items = [
        for (var i = 1; i <= 3; i++) receipt(id: 'r-$i', status: 'saved'),
      ];
    await pump(t, repo);
    expect(find.byKey(const ValueKey('receipt-r-3')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('receipts-more')),
      200,
    );
    await t.tap(find.byKey(const ValueKey('receipts-more')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-r-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('receipts-more')), findsNothing);
  });

  testWidgets('the spend chart sits above the receipts', (t) async {
    final repo = FakeReceipts()
      ..stats_ = const ReceiptStats(
        totalSen: 5615,
        visits: 3,
        months: [(month: '2026-10', visits: 1, totalSen: 4115)],
        places: [
          (
            placeId: 'x',
            name: 'Port Lepak',
            cover: null,
            visits: 2,
            totalSen: 5115,
            lastVisitAt: null,
          ),
          (
            placeId: 'y',
            name: 'Kopi Kita',
            cover: null,
            visits: 1,
            totalSen: 500,
            lastVisitAt: null,
          ),
        ],
      )
      ..items = [receipt(id: 'r-1', status: 'saved')];
    await pump(t, repo);
    expect(find.byKey(const ValueKey('spend-chart')), findsOneWidget);
    expect(find.text('RM 56.15'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Top places'), findsOneWidget);
    // A strip of cards, most spent first, each with its share of the spending.
    expect(find.byKey(const ValueKey('top-place-x')), findsOneWidget);
    expect(find.text('RM 51.15'), findsOneWidget);
    expect(find.text('91% of spending'), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('top-place-y'))).dx,
      greaterThan(t.getTopLeft(find.byKey(const ValueKey('top-place-x'))).dx),
    );
  });
}
