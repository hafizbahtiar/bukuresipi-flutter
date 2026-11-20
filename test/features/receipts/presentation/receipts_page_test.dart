import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipts_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../receipts_fixtures.dart';

void main() {
  late FakeAuthRepository authRepo;

  Future<void> pump(WidgetTester t, FakeReceipts repo) async {
    final auth = AuthController(
      authRepo = FakeAuthRepository()..session = true,
    );
    await auth.restore();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: repo),
          ChangeNotifierProvider.value(value: auth),
        ],
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

  testWidgets('a monthly budget: set it, then this month against it', (
    t,
  ) async {
    final my = DateTime.now().toUtc().add(const Duration(hours: 8));
    final month = '${my.year}-${my.month.toString().padLeft(2, '0')}';
    final repo = FakeReceipts()
      ..stats_ = ReceiptStats(
        totalSen: 90000,
        visits: 3,
        months: [(month: month, visits: 3, totalSen: 90000)],
        places: const [],
      )
      ..items = [receipt(id: 'r-1', status: 'saved')];
    await pump(t, repo);
    await t.tap(find.byKey(const ValueKey('budget-set')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('budget-field')), '800');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(authRepo.budgets, [80000]);
    expect(find.text('This month: RM 900.00 of RM 800.00'), findsOneWidget);
    expect(find.text('RM 100.00 over'), findsOneWidget);
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

  testWidgets(
    'a top place opens its visits: totals, average, each day with its total when it had more than one',
    (t) async {
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = FakeReceipts()
        ..stats_ = const ReceiptStats(
          totalSen: 9000,
          visits: 3,
          months: [],
          places: [
            (
              placeId: 'x',
              name: 'Port Lepak',
              cover: null,
              visits: 3,
              totalSen: 9000,
              lastVisitAt: null,
            ),
          ],
        )
        ..items = [
          receipt(
            id: 'a',
            status: 'saved',
            totalSen: 2000,
            visitedAt: DateTime(2026, 11, 8, 12, 5),
          ),
          receipt(
            id: 'b',
            status: 'saved',
            totalSen: 3000,
            visitedAt: DateTime(2026, 11, 8, 20, 41),
          ),
          receipt(
            id: 'c',
            status: 'saved',
            totalSen: 4000,
            visitedAt: DateTime(2026, 10, 2, 9),
          ),
          receipt(id: 'd'), // still in review: not a visit
        ];
      await pump(t, repo);
      await t.tap(find.byKey(const ValueKey('top-place-x')));
      await t.pumpAndSettle();
      expect(repo.listedPlaces, ['x']);
      final sheet = find.byKey(const ValueKey('place-visits'));
      Finder inSheet(String s) =>
          find.descendant(of: sheet, matching: find.text(s));
      expect(inSheet('RM 90.00'), findsOneWidget); // spent
      expect(inSheet('RM 30.00'), findsNWidgets(2)); // average, and visit b
      // Two visits on Nov 8: the day says its total; one on Oct 2: no total.
      expect(
        find.descendant(of: sheet, matching: find.textContaining('· RM 50.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(const ValueKey('visit-d')),
        ),
        findsNothing,
      );
      // Newest first.
      expect(
        t.getTopLeft(find.byKey(const ValueKey('visit-b'))).dy,
        lessThan(t.getTopLeft(find.byKey(const ValueKey('visit-c'))).dy),
      );
    },
  );
}
