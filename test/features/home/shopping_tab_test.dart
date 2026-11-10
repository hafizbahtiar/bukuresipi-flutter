import 'package:bukuresipi_flutter/features/home/presentation/shopping_tab.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../receipts/receipts_fixtures.dart';
import '../shopping/shopping_fixtures.dart';

void main() {
  testWidgets('the Shopping tab: the list first, Receipts one switch away', (
    t,
  ) async {
    final shopping = ShoppingController(FakeShopping());
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: shopping),
          Provider<ReceiptsRepository>.value(value: FakeReceipts()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: Scaffold(body: ShoppingTab()),
        ),
      ),
    );
    await shopping.load();
    await t.pumpAndSettle();
    expect(find.text('Shopping list'), findsOneWidget);
    await t.tap(find.text('Receipts').first);
    await t.pumpAndSettle();
    expect(find.text('Receipts and spending'), findsOneWidget);
    await t.tap(find.text('List').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Nothing to buy'), findsOneWidget);
  });
}
