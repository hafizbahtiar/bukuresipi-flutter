import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share_repository.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_intake.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import 'share_intake_test.dart' show FakeIncoming, FakeShares;

class PollingShares extends FakeShares {
  int reads = 0;
  @override
  Future<Share> get(String id) async => Share(
    id: id,
    status: ++reads < 2 ? 'processing' : 'done',
    kind: 'restaurant',
    restaurantId: 'r-1',
  );
}

void main() {
  Future<(ShareIntake, FakeIncoming)> pump(
    WidgetTester t,
    FakeShares shares,
  ) async {
    final incoming = FakeIncoming();
    final auth = AuthController(FakeAuthRepository()..session = true);
    await auth.restore();
    final intake = ShareIntake(incoming, shares, auth);
    await intake.start();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ShareRepository>.value(value: shares),
          ChangeNotifierProvider.value(value: intake),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: SharePage(),
        ),
      ),
    );
    return (intake, incoming);
  }

  testWidgets('an accepted share is polled until it is read', (t) async {
    final (_, incoming) = await pump(t, PollingShares());
    incoming.controller.add([
      const Incoming.text('https://www.tiktok.com/@a/video/1'),
    ]);
    await t.pump();
    await t.pump();
    expect(find.textContaining('Reading the post'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(find.text('Saved to your places.'), findsOneWidget);
  });

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
