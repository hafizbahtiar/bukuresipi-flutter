import 'package:bukuresipi_flutter/core/router/unfocus_on_navigation.dart';
import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/register_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes.dart';

void main() {
  testWidgets('login -> register -> back does not focus the email again', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/login',
      observers: [UnfocusOnNavigation()],
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      ],
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthController(FakeAuthRepository()),
          ),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
        ),
      ),
    );
    await t.pumpAndSettle();

    final email = find.byType(TextFormField).first;
    await t.ensureVisible(email);
    await t.tap(email);
    await t.pump();

    EditableText editableOf(Finder field) => t.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

    expect(editableOf(email).focusNode.hasFocus, isTrue);

    final toRegister = find.text('New here? Create an account');
    await t.ensureVisible(toRegister);
    await t.tap(toRegister);
    await t.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);

    final toLogin = find.text('Already have an account? Sign in');
    await t.ensureVisible(toLogin);
    await t.tap(toLogin);
    await t.pumpAndSettle();

    final emailBack = find.byType(TextFormField).first;
    expect(editableOf(emailBack).focusNode.hasFocus, isFalse);
  });
}
