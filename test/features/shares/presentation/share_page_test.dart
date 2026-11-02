import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share_repository.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_intake.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import 'share_intake_test.dart' show FakeCaptions, FakeIncoming, FakeShares;

void main() {
  var left = 0;
  void leave() => left++;

  Future<(ShareIntake, FakeIncoming)> pump(
    WidgetTester t,
    FakeShares shares,
  ) async {
    left = 0;
    final incoming = FakeIncoming();
    final auth = AuthController(FakeAuthRepository()..session = true);
    await auth.restore();
    final intake = ShareIntake(incoming, shares, auth, FakeCaptions());
    await intake.start();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ShareRepository>.value(value: shares),
          ChangeNotifierProvider.value(value: intake),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: SharePage(leave: leave),
        ),
      ),
    );
    return (intake, incoming);
  }

  testWidgets(
    'an accepted share says saved, then goes back to the app it came from',
    (t) async {
      final (_, incoming) = await pump(t, FakeShares());
      incoming.controller.add([
        const Incoming.text('https://www.tiktok.com/@a/video/1'),
      ]);
      await t.pump();
      await t.pump();
      expect(find.textContaining('in your book in a minute'), findsOneWidget);
      expect(left, 0);
      await t.pump(const Duration(seconds: 2));
      expect(left, 1);
    },
  );

  testWidgets('a refused share says why', (t) async {
    final (_, incoming) = await pump(
      t,
      FakeShares()..error = const ApiException('story_link', status: 422),
    );
    incoming.controller.add([
      const Incoming.text('https://www.instagram.com/stories/a/1'),
    ]);
    await t.pump();
    await t.pump();
    expect(find.textContaining('Stories disappear'), findsOneWidget);
  });
}
