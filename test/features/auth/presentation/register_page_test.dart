import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
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
  late FakeAuthRepository repo;

  Future<void> pump(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = FakeAuthRepository();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController(repo)),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: RegisterPage(),
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> submit(WidgetTester t) async {
    final button = find.widgetWithText(FilledButton, 'Create account');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
  }

  testWidgets('the meter and checklist follow what is typed', (t) async {
    await pump(t);
    await t.enterText(field('Password'), 'password1');
    await t.pump();
    expect(find.text('Fair'), findsOneWidget);
    await t.enterText(field('Password'), 'Password1!');
    await t.pump();
    expect(find.text('Strong'), findsOneWidget);
    expect(
      find.byIcon(Icons.check_circle),
      findsNWidgets(5),
    ); // all but "12 characters or more"
  });

  testWidgets('a different confirmation blocks the request', (t) async {
    await pump(t);
    await t.enterText(field('Email'), 'a@example.com');
    await t.enterText(field('Password'), 'Password1!');
    await t.enterText(field('Confirm password'), 'Password1?');
    await submit(t);
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(repo.registered, isEmpty);
  });

  testWidgets('matching passwords register', (t) async {
    await pump(t);
    await t.enterText(field('Email'), 'a@example.com');
    await t.enterText(field('Password'), 'Password1!');
    await t.enterText(field('Confirm password'), 'Password1!');
    await submit(t);
    expect(repo.registered, ['a@example.com']);
  });

  group('back to sign in', () {
    Future<GoRouter> pumpRouted(
      WidgetTester t, {
      required bool fromLogin,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: fromLogin ? '/login' : '/register',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
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
      if (fromLogin) {
        router.push('/register');
        await t.pumpAndSettle();
      }
      return router;
    }

    Future<void> tapSignIn(WidgetTester t) async {
      final link = find.text('Already have an account? Sign in');
      await t.ensureVisible(link);
      await t.tap(link);
      await t.pumpAndSettle();
    }

    testWidgets('came from login: goes back to it, flipping backward', (
      t,
    ) async {
      final router = await pumpRouted(t, fromLogin: true);
      await tapSignIn(t);
      expect(find.text('login page'), findsOneWidget);
      expect(router.canPop(), isFalse, reason: 'popped, not stacked');
    });

    testWidgets('opened directly: still reaches login', (t) async {
      await pumpRouted(t, fromLogin: false);
      await tapSignIn(t);
      expect(find.text('login page'), findsOneWidget);
    });
  });
}
