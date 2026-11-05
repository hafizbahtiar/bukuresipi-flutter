import 'package:bukuresipi_flutter/features/auth/data/auth_api.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/sessions_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends AuthApi {
  _FakeApi() : super(Dio());
  final ended = <String>[];
  var list = <Map<String, dynamic>>[
    {
      'id': 'a',
      'deviceName': 'Infinix HOT 40 Pro',
      'deviceModel': 'Infinix X6731',
      'osVersion': 'Android 14',
      'appVersion': '1.4.0',
      'location': 'Kuala Lumpur, MY',
      'platform': 'android',
      'current': true,
      'createdAt': '2026-11-01T10:00:00Z',
      'lastUsedAt': '2026-11-05T10:00:00Z',
    },
    {
      'id': 'b',
      'deviceName': null,
      'platform': 'android',
      'current': false,
      'createdAt': '2026-10-01T10:00:00Z',
      'lastUsedAt': '2026-11-01T10:00:00Z',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> sessions() async => list;
  @override
  Future<void> endSession(String id) async {
    ended.add(id);
    list = list.where((s) => s['id'] != id).toList();
  }
}

void main() {
  testWidgets('lists this phone first; another device can be signed out', (
    t,
  ) async {
    final api = _FakeApi();
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: SessionsPage(api: api),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Infinix HOT 40 Pro'), findsOneWidget);
    expect(
      find.text('Infinix X6731 · Android 14 · App 1.4.0 · Kuala Lumpur, MY'),
      findsOneWidget,
    );
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('Unknown device'), findsOneWidget);
    await t.tap(
      find.widgetWithText(TextButton, 'Sign out'),
    ); // only the other device has one
    await t.pumpAndSettle();
    await t.tap(find.text('Sign out').last); // the dialog's button
    await t.pumpAndSettle();
    expect(api.ended, ['b']);
    expect(find.text('Unknown device'), findsNothing);
    expect(find.text('Sign out all other devices'), findsNothing);
  });
}
