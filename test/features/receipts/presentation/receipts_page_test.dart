import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipts_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../receipts_fixtures.dart';

void main() {
  testWidgets('Load more brings the next page and goes away on the last', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..pageSize = 2
      ..items = [
        for (var i = 1; i <= 3; i++) receipt(id: 'r-$i', status: 'saved'),
      ];
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

  testWidgets('today against the target; the target is set from here', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..today = (
        eatenKcal: 900,
        target: null,
        hasEstimate: true,
        unknownEaten: 0,
      );
    final auth = FakeAuthRepository();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: repo),
          ChangeNotifierProvider(create: (_) => AuthController(auth)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReceiptsPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('900 kcal'), findsOneWidget);
    repo.today = (
      eatenKcal: 900,
      target: 2000,
      hasEstimate: true,
      unknownEaten: 0,
    );
    await t.tap(find.text('Set a daily target'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('kcal-target')), '2000');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(auth.kcalTargets, [2000]);
    expect(find.text('900 / 2000 kcal'), findsOneWidget);
    expect(find.text('Change target'), findsOneWidget);
  });

  testWidgets('a target outside 500-10,000 is not sent', (t) async {
    final auth = FakeAuthRepository();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: FakeReceipts()),
          ChangeNotifierProvider(create: (_) => AuthController(auth)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReceiptsPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Set a daily target'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('kcal-target')), '50');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(auth.kcalTargets, isEmpty);
  });
}
