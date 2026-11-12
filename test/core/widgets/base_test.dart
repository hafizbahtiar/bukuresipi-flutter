import 'package:bukuresipi_flutter/core/widgets/base.dart';
import 'package:bukuresipi_flutter/core/widgets/notebook_dialog.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pump(WidgetTester t) async {
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
    return ctx;
  }

  testWidgets('dialog: confirm = true, cancel = false, info has no cancel', (
    t,
  ) async {
    final ctx = await pump(t);
    var answer = showBaseDialog(ctx, message: 'Remove?');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dialog-confirm')));
    await t.pumpAndSettle();
    expect(await answer, isTrue);

    answer = showBaseDialog(ctx, message: 'Remove?', tone: DialogTone.danger);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dialog-cancel')));
    await t.pumpAndSettle();
    expect(await answer, isFalse);

    showBaseDialog(ctx, message: 'Done', tone: DialogTone.info);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('dialog-cancel')), findsNothing);
  });

  testWidgets('picker ticks the current option and returns the tapped one', (
    t,
  ) async {
    final ctx = await pump(t);
    final picked = showBasePicker(
      ctx,
      title: 'State',
      options: const ['Selangor', 'Johor'],
      selected: 'Selangor',
      label: (s) => s,
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    await t.tap(find.text('Johor'));
    await t.pumpAndSettle();
    expect(await picked, 'Johor');
  });

  testWidgets(
    'picker search filters; typed text that matches nothing can be used',
    (t) async {
      final ctx = await pump(t);
      final picked = showBasePicker<String>(
        ctx,
        title: 'Town',
        options: const ['Kajang', 'Bangi', 'Kuala Lumpur'],
        selected: null,
        label: (s) => s,
        custom: (typed) => typed,
      );
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('picker-search')), 'ka');
      await t.pump();
      expect(find.text('Kajang'), findsOneWidget);
      expect(find.text('Bangi'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('picker-search')),
        'Taman Melati',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('picker-custom')));
      await t.pumpAndSettle();
      expect(await picked, 'Taman Melati');
    },
  );

  testWidgets('a short picker can go without the search box', (t) async {
    final ctx = await pump(t);
    showBasePicker<String>(
      ctx,
      title: 'List',
      options: const ['Mine', 'Family'],
      selected: null,
      label: (s) => s,
      search: false,
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker-search')), findsNothing);
  });
}
