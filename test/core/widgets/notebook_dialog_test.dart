import 'package:bukuresipi_flutter/core/widgets/notebook_dialog.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Future<bool> Function(DialogTone, {String? confirm})> pump(
    WidgetTester t,
  ) async {
    late BuildContext ctx;
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
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    return (tone, {confirm}) => showNotebookDialog(
      ctx,
      title: 'Remove?',
      message: 'It goes for good.',
      tone: tone,
      confirmLabel: confirm,
    );
  }

  testWidgets(
    'a confirm dialog: the positive button says yes, Cancel says no',
    (t) async {
      final show = await pump(t);
      final yes = show(DialogTone.danger, confirm: 'Remove');
      await t.pumpAndSettle();
      expect(find.text('Remove?'), findsOneWidget);
      expect(find.text('It goes for good.'), findsOneWidget);
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(await yes, isTrue);

      final no = show(DialogTone.confirm, confirm: 'Go');
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(await no, isFalse);
    },
  );

  testWidgets('an info dialog has one button, OK', (t) async {
    final show = await pump(t);
    final done = show(DialogTone.info);
    await t.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(await done, isTrue);
  });

  testWidgets('tapping outside is a no', (t) async {
    final show = await pump(t);
    final no = show(DialogTone.confirm, confirm: 'Go');
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(await no, isFalse);
  });
}
