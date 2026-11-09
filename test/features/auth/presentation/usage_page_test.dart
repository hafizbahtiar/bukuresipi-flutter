import 'package:bukuresipi_flutter/features/auth/data/auth_api.dart';
import 'package:bukuresipi_flutter/features/auth/domain/usage.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/usage_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

class _FakeApi extends AuthApi {
  _FakeApi() : super(Dio());
  @override
  Future<Usage> usage() async => Usage.fromJson({
    'items': [
      {'code': 'shares', 'used': 3, 'limit': 20, 'period': 'day'},
      {'code': 'receipts', 'used': 10, 'limit': 10, 'period': 'day'},
      {'code': 'reports', 'used': 0, 'limit': 20, 'period': 'day'},
      {'code': 'shopping', 'used': 12, 'limit': 200, 'period': 'total'},
    ],
    'resetsAt': '2026-11-09T00:00:00.000Z',
  });
}

void main() {
  Future<void> pump(WidgetTester t, String role) async {
    final repo = FakeAuthRepository()
      ..session = true
      ..meResult = User(
        id: 'u-1',
        email: 'a@example.com',
        name: 'Ali',
        role: role,
        lang: 'en',
        emailVerified: true,
      );
    final auth = AuthController(repo);
    await auth.restore();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UsagePage(api: _FakeApi()),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'a user sees their own limits; a full one is marked; no service meters',
    (t) async {
      await pump(t, 'user');
      expect(find.text('Receipt photos today'), findsOneWidget);
      expect(find.text('10 / 10'), findsOneWidget);
      expect(find.text('3 / 20'), findsOneWidget);
      expect(find.text('12 / 200'), findsOneWidget);
      expect(
        find.textContaining('Daily counts start again at'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('usage-meters')), findsNothing);
    },
  );

  testWidgets('the owner also gets the service meters', (t) async {
    await pump(t, 'owner');
    expect(find.byKey(const ValueKey('usage-meters')), findsOneWidget);
  });
}
