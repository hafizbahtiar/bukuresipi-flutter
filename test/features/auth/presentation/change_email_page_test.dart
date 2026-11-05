import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/change_email_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

void main() {
  Future<void> pump(WidgetTester t, FakeAuthRepository repo) => t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthController(repo),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ms')],
        home: ChangeEmailPage(),
      ),
    ),
  );

  Future<void> fill(WidgetTester t) async {
    await t.enterText(
      find.widgetWithText(TextFormField, 'New email'),
      ' baru@example.com ',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'pw',
    );
    final button = find.text('Send confirmation link');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
  }

  testWidgets(
    'sends the link and says the email changes only once it is opened',
    (t) async {
      final repo = FakeAuthRepository();
      await pump(t, repo);
      await fill(t);
      expect(repo.emailChanges, ['baru@example.com']);
      expect(
        find.textContaining('We sent a link to baru@example.com'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a taken address or wrong password is shown on the form', (
    t,
  ) async {
    final repo = FakeAuthRepository()
      ..changeEmailError = const ApiException('email_taken', status: 409);
    await pump(t, repo);
    await fill(t);
    expect(
      find.text('Another account already uses this email.'),
      findsOneWidget,
    );
    repo.changeEmailError = const ApiException(
      'invalid_credentials',
      status: 401,
    );
    await t.tap(find.text('Send confirmation link'));
    await t.pumpAndSettle();
    expect(find.text('The current password is wrong.'), findsOneWidget);
  });
}
