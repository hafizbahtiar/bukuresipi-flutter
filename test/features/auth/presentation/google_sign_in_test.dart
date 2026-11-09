import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/data/google_auth.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/settings_page.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/delete_account_page.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes.dart';

class _FakeGoogle implements GoogleAuth {
  String? token = 'google-id-token';
  @override
  Future<String?> idToken() async => token;
  @override
  Future<void> signOut() async {}
}

const _googleOnly = User(
  id: 'u-1',
  email: 'ali@gmail.com',
  name: 'Ali',
  role: 'user',
  lang: 'ms',
  emailVerified: true,
  hasPassword: false,
  google: true,
);

void main() {
  late FakeAuthRepository repo;
  late AuthController auth;

  Future<void> pump(
    WidgetTester t,
    Widget page, {
    GoogleAuth? google,
    User? user,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final locale = LocaleController(await SharedPreferences.getInstance());
    repo = FakeAuthRepository();
    if (user != null) {
      repo
        ..session = true
        ..meResult = user
        ..cached = user;
    }
    auth = AuthController(repo);
    await auth.restore();
    t.view.physicalSize = const Size(1080, 3000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GoogleAuth?>.value(value: google),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('no Google set up: no Google button', (t) async {
    await pump(t, const LoginPage());
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('Continue with Google sends the ID token and signs in', (
    t,
  ) async {
    await pump(t, const LoginPage(), google: _FakeGoogle());
    expect(
      find.image(const AssetImage('assets/brand/google_g.png')),
      findsOneWidget,
    );
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(repo.googleTokens, ['google-id-token']);
    expect(auth.status, AuthStatus.signedIn);
  });

  testWidgets(
    'closing the Google sheet does nothing; an API refusal shows in words',
    (t) async {
      final google = _FakeGoogle()..token = null;
      await pump(t, const LoginPage(), google: google);
      await t.tap(find.text('Continue with Google'));
      await t.pumpAndSettle();
      expect(repo.googleTokens, isEmpty);
      google.token = 't';
      repo.loginError = const ApiException(
        'google_account_mismatch',
        status: 409,
      );
      await t.tap(find.text('Continue with Google'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('already linked to a different Google account'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a Google-only account: "Set a password", and changing the email waits for one',
    (t) async {
      await pump(t, const SettingsPage(), user: _googleOnly);
      expect(find.text('Set a password'), findsOneWidget);
      expect(find.text('Change password'), findsNothing);
      expect(
        find.text('Set a password first to change your email.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a Google-only account deletes itself with Google, not a password',
    (t) async {
      await pump(
        t,
        const DeleteAccountPage(),
        google: _FakeGoogle(),
        user: _googleOnly,
      );
      expect(find.byType(TextFormField), findsNothing);
      await t.tap(find.text('Confirm with Google'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('dialog-confirm')));
      await t.pumpAndSettle();
      expect(repo.deleted, ['google:google-id-token']);
    },
  );

  testWidgets(
    'Account > Google: link with the Google sheet, then unlink after asking',
    (t) async {
      await pump(
        t,
        const SettingsPage(),
        google: _FakeGoogle(),
        user: testUser,
      );
      expect(
        find.text('Link your Google account to sign in with one tap'),
        findsOneWidget,
      );
      await t.tap(find.text('Google'));
      await t.pumpAndSettle();
      expect(repo.googleTokens, ['link:google-id-token']);
      expect(
        find.text('Linked: you can sign in with Google or your password'),
        findsOneWidget,
      );
      await t.tap(find.text('Unlink'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('dialog-confirm')));
      await t.pumpAndSettle();
      expect(auth.user!.google, isFalse);
    },
  );

  testWidgets('a Google-only account cannot unlink (no other way in)', (
    t,
  ) async {
    await pump(
      t,
      const SettingsPage(),
      google: _FakeGoogle(),
      user: _googleOnly,
    );
    expect(
      find.text(
        'Linked: you sign in with Google. Set a password to unlink it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Unlink'), findsNothing);
  });

  testWidgets('no Google on this phone and not linked: no Google row', (
    t,
  ) async {
    await pump(t, const SettingsPage(), user: testUser);
    expect(find.text('Google'), findsNothing);
  });
}
