import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/core/widgets/pill_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pill over two pages, wired as the recipe and receipt pages do.
class _Tabs extends StatefulWidget {
  const _Tabs();
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final pages = PageController();
  int value = 0;
  final changed = <int>[];

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PillSwitch<int>(
        key: const ValueKey('pill'),
        expand: true,
        value: value,
        onChanged: (_) => fail('with pages, the PageView reports the change'),
        pages: pages,
        options: const [(0, Text('One'), null), (1, Text('Two'), null)],
      ),
      Expanded(
        child: PageView(
          key: const ValueKey('pages'),
          controller: pages,
          onPageChanged: (i) => setState(() {
            value = i;
            changed.add(i);
          }),
          children: const [
            Center(child: Text('page one')),
            Center(child: Text('page two')),
          ],
        ),
      ),
    ],
  );
}

Future<_TabsState> _pump(WidgetTester t) async {
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [Notebook.light]),
      home: const Scaffold(body: _Tabs()),
    ),
  );
  await t.pumpAndSettle();
  return t.state<_TabsState>(find.byType(_Tabs));
}

/// The chip: the pill's DecoratedBox with a shadow.
Rect _chip(WidgetTester t) => t.getRect(
  find.descendant(
    of: find.byKey(const ValueKey('pill')),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).boxShadow != null,
    ),
  ),
);

void main() {
  testWidgets(
    'swiping the content moves the pages, and the chip follows the finger',
    (t) async {
      final s = await _pump(t);
      final one = _chip(t);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('pages'))),
      );
      await g.moveBy(const Offset(-200, 0));
      await t.pump();
      expect(
        find.text('page two'),
        findsOneWidget,
      ); // the next page shows mid-swipe
      final mid = _chip(t);
      expect(mid.left, greaterThan(one.left));
      await g.moveBy(const Offset(-200, 0));
      await g.up();
      await t.pumpAndSettle();
      expect(s.value, 1);
      expect(find.text('page one'), findsNothing);
      expect(_chip(t).left, greaterThan(mid.left));
    },
  );

  testWidgets('dragging the pill drags the pages; a tap animates to the page', (
    t,
  ) async {
    final s = await _pump(t);
    // Half a segment (~200 px here) is half a page: past it, the pill settles on Two.
    await t.drag(find.byKey(const ValueKey('pill')), const Offset(250, 0));
    await t.pumpAndSettle();
    expect(s.value, 1);
    expect(find.text('page two'), findsOneWidget);

    await t.tap(find.text('One'));
    await t.pumpAndSettle();
    expect(s.value, 0);
    expect(find.text('page one'), findsOneWidget);
    expect(s.changed, [1, 0]);
  });
}
