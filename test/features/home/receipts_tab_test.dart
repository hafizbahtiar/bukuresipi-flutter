import 'package:bukuresipi_flutter/features/home/presentation/receipts_tab.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../receipts/receipts_fixtures.dart';

void main() {
  testWidgets('the Receipts tab: spending first, Calories one switch away', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..today = (
        eatenKcal: 900,
        target: 2000,
        hasEstimate: false,
        unknownEaten: 0,
        receipts: const [],
      );
    await t.pumpWidget(
      Provider<ReceiptsRepository>.value(
        value: repo,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: ReceiptsTab(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Receipts and spending'), findsOneWidget);
    expect(find.text('Calories'), findsWidgets);

    // One page: the switch changes what is under it (the hidden side is kept, offstage) and the title.
    expect(find.text('900 / 2000 kcal'), findsNothing);
    expect(find.byKey(const ValueKey('spend-chart')), findsOneWidget);

    await t.tap(find.text('Calories').first);
    await t.pumpAndSettle();
    expect(find.text('900 / 2000 kcal'), findsOneWidget);
    expect(find.byKey(const ValueKey('spend-chart')), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);

    await t.tap(find.text('Receipts').first);
    await t.pumpAndSettle();
    expect(find.text('Receipts and spending'), findsOneWidget);
    expect(find.byKey(const ValueKey('spend-chart')), findsOneWidget);
  });

  testWidgets(
    'a switch reloads in place (no spinner); pulling from the header refreshes',
    (t) async {
      final repo = FakeReceipts();
      await t.pumpWidget(
        Provider<ReceiptsRepository>.value(
          value: repo,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ms')],
            home: ReceiptsTab(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Calories').first);
      await t.pump(); // the reload has started, its answer not yet in
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pumpAndSettle();

      // Back on Receipts: pull down from the very top of the page (the chart).
      await t.tap(find.text('Receipts').first);
      await t.pumpAndSettle();
      final calls = repo.statCalls;
      await t.fling(
        find.byKey(const ValueKey('spend-chart')),
        const Offset(0, 400),
        1000,
      );
      await t.pumpAndSettle();
      expect(repo.statCalls, greaterThan(calls));
    },
  );
}
