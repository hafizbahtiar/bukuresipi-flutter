import 'package:bukuresipi_flutter/features/family/presentation/ask.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'askText returns the typed text; the closing animation does not use a disposed controller',
    (t) async {
      String? answer = 'unset';
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await askText(
                context,
                title: 'Family',
                message: 'Name it',
                confirmLabel: 'Create',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '  Rumah Ali  ');
      await t.tap(find.text('Create'));
      await t.pumpAndSettle(); // plays the whole closing animation: the old code threw here
      expect(t.takeException(), isNull);
      expect(answer, 'Rumah Ali');
    },
  );
}
