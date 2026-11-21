import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/home/presentation/add_sheet.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_intake.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../../shares/presentation/share_intake_test.dart'
    show FakeCaptions, FakeIncoming, FakeShares;

void main() {
  testWidgets(
    'Paste a link: a sheet with Paste; adding closes it cleanly and sends the link',
    (t) async {
      final shares = FakeShares();
      final auth = AuthController(FakeAuthRepository()..session = true);
      await auth.restore();
      final intake = ShareIntake(FakeIncoming(), shares, auth, FakeCaptions());
      await intake.start();
      const link = 'https://maps.app.goo.gl/VqWrfFt4FTQYNESR8';
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': ' $link '};
          return null;
        },
      );
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: intake,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAddSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('add-link')));
      await t.pumpAndSettle();
      final add = find.byKey(const ValueKey('add-link-submit'));
      expect(
        t.widget<FilledButton>(add).onPressed,
        isNull,
      ); // nothing to add yet
      await t.tap(find.byKey(const ValueKey('add-link-paste')));
      await t.pumpAndSettle();
      await t.tap(add);
      await t.pumpAndSettle(); // the sheet's closing animation used to hit a disposed field
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('add-link-field')), findsNothing);
      expect(shares.sent, ['link:$link']);
    },
  );

  testWidgets(
    'Receipt and Meal ask camera or photos in the same sheet (its next step), never a second sheet',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAddSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      for (final (row, camera) in [
        ('add-meal', 'Snap a meal'),
        ('add-receipt', 'Snap a receipt'),
      ]) {
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final sheet = ModalRoute.of(t.element(find.byKey(ValueKey(row))));
        await t.tap(find.byKey(ValueKey(row)));
        await t.pumpAndSettle();
        expect(find.byKey(ValueKey(row)), findsNothing); // the menu has gone
        final tile = find.byKey(const ValueKey('photo-camera'));
        expect(
          find.descendant(of: tile, matching: find.text(camera)),
          findsOneWidget,
        );
        expect(
          ModalRoute.of(t.element(tile)),
          same(sheet),
        ); // the same sheet, not a new one
        expect(
          find.byType(ModalBarrier),
          findsNWidgets(2),
        ); // the app's own + one sheet
        await t.tapAt(const Offset(10, 10)); // close
        await t.pumpAndSettle();
        expect(tile, findsNothing);
      }
      expect(t.takeException(), isNull);
    },
  );
}
