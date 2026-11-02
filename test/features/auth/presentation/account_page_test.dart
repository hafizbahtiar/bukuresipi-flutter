import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/account_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes.dart';

void main() {
  late LocaleController locale;
  late FakeAuthRepository repo;

  Future<void> pump(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    locale = LocaleController(await SharedPreferences.getInstance());
    repo = FakeAuthRepository()..session = true;
    final auth = AuthController(repo);
    await auth.restore();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: AccountPage(),
        ),
      ),
    );
  }

  testWidgets(
    'the account page: who, email not confirmed yet (resend), language, sign out',
    (t) async {
      await pump(t);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('a@example.com'), findsOneWidget);
      expect(find.text('Send confirmation email again'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      await t.tap(find.text('EN'));
      await t.pump();
      expect(locale.lang, 'en');
      await t.tap(find.text('BM'));
      await t.pump();
      expect(locale.lang, 'ms');
    },
  );

  testWidgets('sign out asks first', (t) async {
    await pump(t);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(repo.clears, 0);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await t.pumpAndSettle();
    expect(repo.clears, 1);
  });
}
