import 'package:bukuresipi_flutter/features/auth/data/google_auth.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/pages/delete_account_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

void main() {
  testWidgets(
    'opened from its link (alone on the stack): the device back goes Home, not out of the app',
    (t) async {
      final auth = AuthController(FakeAuthRepository());
      await auth.restore();
      final router = GoRouter(
        initialLocation: '/auth/delete',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/auth/delete',
            builder: (_, _) => const DeleteAccountPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<GoogleAuth?>.value(value: null),
            ChangeNotifierProvider.value(value: auth),
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
      expect(find.byType(DeleteAccountPage), findsOneWidget);
      // Android back: true = the app handled it (it did not close).
      expect(await t.binding.handlePopRoute(), isTrue);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    },
  );
}
