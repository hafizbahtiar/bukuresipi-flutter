import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/data/auth_api.dart';
import 'package:bukuresipi_flutter/features/auth/data/passkey_auth.dart';
import 'package:bukuresipi_flutter/features/auth/domain/passkey.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/passkeys_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

/// The phone: answers with a fixed credential, closes the sheet (null) or fails with a code.
class _FakePhone implements PasskeyAuth {
  Map<String, dynamic>? answer = {
    'id': 'cred-1',
    'response': <String, dynamic>{},
  };
  String? error;
  final asked = <Map<String, dynamic>>[];

  Future<Map<String, dynamic>?> _go(Map<String, dynamic> options) async {
    asked.add(options);
    if (error != null) throw ApiException(error!);
    return answer;
  }

  @override
  Future<Map<String, dynamic>?> create(Map<String, dynamic> options) =>
      _go(options);
  @override
  Future<Map<String, dynamic>?> get(Map<String, dynamic> options) =>
      _go(options);
}

class _FakeApi extends AuthApi {
  _FakeApi() : super(Dio());
  final removed = <String>[];
  final added = <Map<String, dynamic>>[];
  var list = <Passkey>[
    Passkey.fromJson(const {
      'id': 'p-1',
      'name': 'Pixel 8',
      'createdAt': '2026-11-01T10:00:00Z',
      'lastUsedAt': null,
    }),
  ];

  @override
  Future<List<Passkey>> passkeys() async => list;
  @override
  Future<Map<String, dynamic>> passkeyRegisterOptions() async => {
    'challenge': 'c-9',
  };
  @override
  Future<Passkey> addPasskey(Map<String, dynamic> response) async {
    added.add(response);
    final p = Passkey.fromJson(const {
      'id': 'p-2',
      'name': 'Infinix HOT 40 Pro',
      'createdAt': '2026-11-13T10:00:00Z',
      'lastUsedAt': null,
    });
    list = [...list, p];
    return p;
  }

  @override
  Future<void> deletePasskey(String id) async {
    removed.add(id);
    list = list.where((p) => p.id != id).toList();
  }
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('ms')],
  home: home,
);

void main() {
  group('login', () {
    late FakeAuthRepository repo;
    late AuthController auth;

    Future<void> pump(WidgetTester t, PasskeyAuth? phone) async {
      repo = FakeAuthRepository();
      auth = AuthController(repo);
      await auth.restore();
      t.view.physicalSize = const Size(1080, 3000);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PasskeyAuth?>.value(value: phone),
            ChangeNotifierProvider.value(value: auth),
          ],
          child: _app(const LoginPage()),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('a phone without passkeys shows no button', (t) async {
      await pump(t, null);
      expect(find.text('Sign in with a passkey'), findsNothing);
    });

    testWidgets("the API's challenge goes to the phone; its answer signs in", (
      t,
    ) async {
      final phone = _FakePhone();
      await pump(t, phone);
      await t.tap(find.text('Sign in with a passkey'));
      await t.pumpAndSettle();
      expect(phone.asked.single['challenge'], 'c-1');
      expect(repo.passkeyLogins.single['id'], 'cred-1');
      expect(auth.status, AuthStatus.signedIn);
    });

    testWidgets('closing the sheet does nothing; no passkey says what to do', (
      t,
    ) async {
      final phone = _FakePhone()..answer = null;
      await pump(t, phone);
      await t.tap(find.text('Sign in with a passkey'));
      await t.pumpAndSettle();
      expect(auth.status, AuthStatus.signedOut);
      expect(repo.passkeyLogins, isEmpty);

      phone.error = 'no_passkey';
      await t.tap(find.text('Sign in with a passkey'));
      await t.pumpAndSettle();
      expect(find.textContaining('No Bukuresipi passkey'), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });
  });

  group('Account > Passkeys', () {
    testWidgets('lists, creates one with the phone, removes one', (t) async {
      final api = _FakeApi();
      final phone = _FakePhone();
      await t.pumpWidget(_app(PasskeysPage(api: api, passkeys: phone)));
      await t.pumpAndSettle();
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.textContaining('Not used yet'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('passkey-add')));
      await t.pumpAndSettle();
      expect(phone.asked.single['challenge'], 'c-9');
      expect(api.added.single['id'], 'cred-1');
      expect(find.text('Infinix HOT 40 Pro'), findsOneWidget);

      await t.tap(find.widgetWithText(TextButton, 'Remove').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Remove').last); // the dialog's confirm
      await t.pumpAndSettle();
      expect(api.removed, ['p-1']);
      expect(find.text('Pixel 8'), findsNothing);
    });

    testWidgets('a closed sheet adds nothing; a phone that cannot says so', (
      t,
    ) async {
      final api = _FakeApi();
      await t.pumpWidget(
        _app(PasskeysPage(api: api, passkeys: _FakePhone()..answer = null)),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('passkey-add')));
      await t.pumpAndSettle();
      expect(api.added, isEmpty);

      await t.pumpWidget(
        Provider<PasskeyAuth?>.value(
          value: null,
          child: _app(PasskeysPage(key: UniqueKey(), api: api)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('passkey-add')), findsNothing);
      expect(find.textContaining("can't create passkeys"), findsOneWidget);
    });
  });
}
