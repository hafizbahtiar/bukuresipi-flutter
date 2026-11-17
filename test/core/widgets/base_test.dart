import 'dart:async';

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

  testWidgets(
    'a floating sheet sits off the screen edges; floating: false is full width',
    (t) async {
      // A phone: on a wide screen Material centres every sheet at 640 dp.
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final ctx = await pump(t);
      final screen = t.view.physicalSize / t.view.devicePixelRatio;

      Future<String?> open() => showBaseSheet<String>(
        ctx,
        builder: (s) => ListTile(
          key: const ValueKey('sheet-row'),
          title: const Text('Pick'),
          onTap: () => Navigator.pop(s, 'picked'),
        ),
      );
      Rect card() => t.getRect(
        find
            .ancestor(
              of: find.byKey(const ValueKey('sheet-row')),
              matching: find.byType(Material),
            )
            .first,
      );

      var answer = open();
      // Half way in: the bottom edge is already on its line; only the top has further to rise.
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      final growing = card();
      await t.pumpAndSettle();
      final open_ = card();
      expect(open_.left, 12);
      expect(screen.width - open_.right, 12);
      expect(screen.height - open_.bottom, 12);
      expect(growing.bottom, open_.bottom);
      expect(growing.height, lessThan(open_.height));
      await t.tap(find.byKey(const ValueKey('sheet-row')));
      await t.pumpAndSettle();
      expect(await answer, 'picked');

      // Dragged down past a third: it closes, with nothing picked.
      answer = open();
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const ValueKey('sheet-row')),
        const Offset(0, 60),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-row')), findsNothing);
      expect(await answer, isNull);

      unawaited(
        showBaseSheet<void>(
          ctx,
          floating: false,
          builder: (_) => const SizedBox(key: ValueKey('wide'), height: 40),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(BottomSheet)).width, screen.width);
    },
  );
}
