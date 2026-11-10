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
          home: ReceiptsPage(),
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
          (restaurantId: 'x', name: 'Port Lepak', visits: 2, totalSen: 5115),
        ],
      )
      ..items = [receipt(id: 'r-1', status: 'saved')];
    await pump(t, repo);
    expect(find.byKey(const ValueKey('spend-chart')), findsOneWidget);
    expect(find.text('RM 56.15'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Top places'), findsOneWidget);
  });

  testWidgets(
    'a scroll down folds the header away; a scroll up brings it back',
    (t) async {
      final repo = FakeReceipts()
        ..items = [
          for (var i = 1; i <= 10; i++) receipt(id: 'r-$i', status: 'saved'),
        ];
      await pump(t, repo);
      expect(find.byKey(const ValueKey('spend-chart')), findsOneWidget);
      final header = find.byKey(const ValueKey('receipts-header'));
      expect(t.getSize(header).height, greaterThan(0));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(t.getSize(header).height, 0);
      await t.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(t.getSize(header).height, greaterThan(0));
    },
  );

  testWidgets('pulling down refreshes the stats and the list', (t) async {
    final repo = FakeReceipts();
    await pump(t, repo);
    expect(repo.statCalls, 1);
    await t.fling(find.byType(CustomScrollView), const Offset(0, 320), 1000);
    await t.pumpAndSettle();
    expect(repo.statCalls, 2);
  });
}
