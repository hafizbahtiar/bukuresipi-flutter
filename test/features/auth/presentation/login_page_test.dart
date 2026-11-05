import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/login_page.dart';
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
        home: LoginPage(),
      ),
    ),
  );

  testWidgets('an invalid email is caught before any request', (t) async {
    final repo = FakeAuthRepository()
      ..loginError = StateError('must not be called');
    await pump(t, repo);
    await t.enterText(find.byType(TextFormField).first, 'not-an-email');
    final button = find.widgetWithText(FilledButton, 'Sign in');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('wrong password shows the API error in words', (t) async {
    await pump(
      t,
      FakeAuthRepository()
        ..loginError = const ApiException('invalid_credentials', status: 401),
    );
    await t.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await t.enterText(find.byType(TextFormField).at(1), 'whatever');
    final button = find.widgetWithText(FilledButton, 'Sign in');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);
  });
}
