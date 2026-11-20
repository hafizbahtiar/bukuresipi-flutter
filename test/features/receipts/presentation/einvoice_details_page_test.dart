import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/einvoice_details.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/einvoice_details_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../receipts_fixtures.dart';

void main() {
  testWidgets(
    'loads the account\'s saved details and saves the edits on the phone, per account',
    (t) async {
      final auth = AuthController(FakeAuthRepository()..session = true);
      await auth.restore();
      final store = FakeEinvoiceDetails()
        ..saved[testUser.id] = const EinvoiceDetails(name: 'Ali bin Abu')
        ..saved['someone-else'] = const EinvoiceDetails(tin: 'NOT-MINE');
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<EinvoiceDetailsStore>.value(value: store),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ms')],
            home: EinvoiceDetailsPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Ali bin Abu'), findsOneWidget);
      expect(find.text('NOT-MINE'), findsNothing);
      await t.enterText(find.byKey(const ValueKey('einvoice-tin')), ' IG123 ');
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('einvoice-details-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.byKey(const ValueKey('einvoice-details-save')));
      await t.pumpAndSettle();
      expect(store.saved[testUser.id]!.tin, 'IG123');
      expect(store.saved[testUser.id]!.name, 'Ali bin Abu');
      expect(find.text('Saved on this phone'), findsOneWidget);
    },
  );
}
