import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

void main() {
  Future<GoRouter> pumpRouted(WidgetTester t, {required bool fromLogin}) async {
    final router = GoRouter(
      initialLocation: fromLogin ? '/login' : '/forgot',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
        GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordPage()),
      ],
    );
    await t.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(FakeAuthRepository()),
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
    if (fromLogin) {
      router.push('/forgot');
      await t.pumpAndSettle();
    }
    return router;
  }

  Future<void> tapSignIn(WidgetTester t) async {
    final link = find.text('Go to sign in');
    await t.ensureVisible(link);
    await t.tap(link);
    await t.pumpAndSettle();
  }

  group('back to sign in', () {
    testWidgets('came from login: pops, not stacks', (t) async {
      final router = await pumpRouted(t, fromLogin: true);
      await tapSignIn(t);
      expect(find.text('login page'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets('opened directly: still reaches login', (t) async {
      await pumpRouted(t, fromLogin: false);
      await tapSignIn(t);
      expect(find.text('login page'), findsOneWidget);
    });

    testWidgets('the back arrow from a deep link also reaches login', (
      t,
    ) async {
      await pumpRouted(t, fromLogin: false);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.text('login page'), findsOneWidget);
    });
  });

  testWidgets('sending the email shows the private-answer message', (t) async {
    await pumpRouted(t, fromLogin: false);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@example.com',
    );
    final button = find.widgetWithText(FilledButton, 'Send link');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.textContaining('If this email is registered'), findsOneWidget);
  });
}
