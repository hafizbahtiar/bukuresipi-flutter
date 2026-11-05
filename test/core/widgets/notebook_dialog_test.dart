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
      expect(find.text('MEMO'), findsOneWidget);
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

  Future<Future<bool>> open(
    WidgetTester t, {
    Size size = const Size(400, 800),
    double textScale = 1,
    String message = 'It goes for good.',
    String confirm = 'Remove',
    String? title = 'Remove?',
  }) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final answer = showNotebookDialog(
      ctx,
      title: title,
      message: message,
      tone: DialogTone.danger,
      confirmLabel: confirm,
    );
    await t.pumpAndSettle();
    return answer;
  }

  final yes = find.byKey(const ValueKey('dialog-confirm'));
  final no = find.byKey(const ValueKey('dialog-cancel'));

  testWidgets('short labels: one row, Cancel left, the answer right', (
    t,
  ) async {
    await open(t);
    expect(t.getCenter(yes).dy, t.getCenter(no).dy);
    expect(t.getCenter(yes).dx, greaterThan(t.getCenter(no).dx));
  });

  testWidgets('labels that do not fit: stacked full width, the answer on top', (
    t,
  ) async {
    final answer = await open(
      t,
      size: const Size(320, 700),
      confirm: 'Log keluar semua peranti lain sekarang',
    );
    expect(t.takeException(), isNull);
    expect(t.getCenter(yes).dy, lessThan(t.getCenter(no).dy));
    expect(t.getSize(yes).width, t.getSize(no).width);
    await t.tap(yes);
    await t.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('big text stacks the buttons too, and nothing overflows', (
    t,
  ) async {
    await open(t, size: const Size(360, 700), textScale: 2);
    expect(t.takeException(), isNull);
    expect(t.getCenter(yes).dy, lessThan(t.getCenter(no).dy));
  });

  testWidgets('a long message scrolls; the buttons stay on screen', (t) async {
    await open(
      t,
      size: const Size(360, 500),
      message: List.filled(60, 'Words that go on.').join(' '),
    );
    expect(t.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(t.getRect(yes).bottom, lessThanOrEqualTo(500));
    expect(t.getRect(no).bottom, lessThanOrEqualTo(500));
  });

  testWidgets('on a tablet the memo stays memo-sized', (t) async {
    await open(t, size: const Size(1200, 900));
    final paper = find
        .ancestor(of: find.text('MEMO'), matching: find.byType(CustomPaint))
        .first;
    expect(t.getSize(paper).width, lessThanOrEqualTo(420));
  });

  testWidgets('no title: the icon sits beside the message', (t) async {
    await open(t, title: null);
    final icon = find.byIcon(Icons.warning_amber_rounded);
    expect(
      t.getCenter(icon).dx,
      lessThan(t.getTopLeft(find.text('It goes for good.')).dx),
    );
  });
}
