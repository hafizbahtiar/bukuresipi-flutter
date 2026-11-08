import 'dart:async';

import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/account_page.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/settings_page.dart';
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

  Future<void> pump(WidgetTester t, [Widget page = const AccountPage()]) async {
    SharedPreferences.setMockInitialValues({});
    locale = LocaleController(await SharedPreferences.getInstance());
    repo = FakeAuthRepository()..session = true;
    final auth = AuthController(repo);
    await auth.restore();
    // A tall phone: the whole page (Name, Family rows included) without scrolling.
    t.view.physicalSize = const Size(1080, 2800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MultiProvider(
        providers: [
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
  }

  testWidgets(
    'the account page: who, email not confirmed yet (resend), sign out; the rest is in Settings',
    (t) async {
      await pump(t);
      expect(
        find.text('Ali'),
        findsNWidgets(2),
      ); // the heading and the Name row
      expect(find.text('a@example.com'), findsOneWidget);
      // Not confirmed: a small "Verify" chip beside the email; tapping it sends the link again.
      expect(find.text('Verify'), findsOneWidget);
      await t.tap(find.text('Verify'));
      await t.pump();
      expect(repo.resends, 1);
      expect(
        find.text('Send confirmation email again'),
        findsNothing,
      ); // no separate row any more
      expect(find.text('Sign out'), findsOneWidget);
      expect(
        find.byType(CircleAvatar),
        findsOneWidget,
      ); // the picture, or the initial
      // Settings (language, email, password, devices, about) has its own page now.
      expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);
      expect(find.text('EN'), findsNothing);
      expect(find.text('Signed-in devices'), findsNothing);
      // Everyone has Usage (their own limits).
      expect(find.byKey(const ValueKey('account-usage')), findsOneWidget);
    },
  );

  testWidgets('settings: language switch', (t) async {
    await pump(t, const SettingsPage());
    expect(find.byType(SegmentedButton<String>), findsNothing);
    await t.tap(find.text('EN'));
    await t.pump();
    expect(locale.lang, 'en');
    await t.tap(find.text('BM'));
    await t.pump();
    expect(locale.lang, 'ms');
  });

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

  testWidgets('settings links to About and the credits', (t) async {
    await pump(t, const SettingsPage());
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
  });

  testWidgets('a long email is cut with … and the chip stays on screen', (
    t,
  ) async {
    await pump(t);
    t.view.physicalSize = const Size(
      480,
      2800,
    ); // 240 dp: too narrow for the whole email
    await t.pump();
    final email = t.widget<Text>(find.text('a@example.com'));
    expect((email.maxLines, email.overflow), (1, TextOverflow.ellipsis));
    expect(t.takeException(), isNull); // no overflow stripe
    expect(t.getRect(find.text('Verify')).right, lessThanOrEqualTo(240));
    final p = TextPainter(
      text: TextSpan(text: email.data, style: email.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: t.getSize(find.text('a@example.com')).width);
    expect(
      p.didExceedMaxLines,
      isTrue,
    ); // it really is cut, not just allowed to be
  });

  testWidgets(
    'the picture: no photo shows the initial; with one, Remove sends the delete',
    (t) async {
      await pump(t);
      expect(find.text('A'), findsOneWidget); // Ali's initial
      await t.tap(find.byKey(const ValueKey('account-avatar')));
      await t.pumpAndSettle();
      expect(find.text('Add profile picture'), findsOneWidget);
      expect(find.text('Remove profile picture'), findsNothing);
      await t.tapAt(const Offset(10, 10)); // close the sheet
      await t.pumpAndSettle();

      repo.meResult = User(
        id: testUser.id,
        email: testUser.email,
        name: testUser.name,
        role: testUser.role,
        lang: testUser.lang,
        emailVerified: false,
        avatar: 'av-1',
      );
      unawaited(
        t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
      ); // completes only as frames are pumped
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('account-avatar')));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove profile picture'));
      await t.pumpAndSettle();
      expect(repo.avatarsRemoved, 1);
    },
  );
}
