import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/receipts_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
}
