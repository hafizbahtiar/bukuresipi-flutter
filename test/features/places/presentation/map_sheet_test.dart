import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 400 x 800 map with the sheet on it; [shown] / [showClose] as the map page passes them.
class _Host extends StatefulWidget {
  const _Host({required this.closed});

  final List<Object?> closed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final controller = DraggableScrollableController();
  int shown = 0;
  bool picked = false;

  void pick() => setState(() {
    picked = true;
    shown++;
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: MapSheet(
          controller: controller,
          peek: 80,
          top: 100,
          shown: shown,
          showClose: picked,
          onClose: (r) {
            widget.closed.add(r);
            setState(() {
              picked = false;
              shown++;
            });
          },
          child: Builder(
            builder: (context) => ListView(
              children: [
                const Text('Title'),
                // A content's "done", as the place sheets call it.
                TextButton(
                  onPressed: () => sheetCloser(context)('saved'),
                  child: const Text('Done'),
                ),
                for (var i = 0; i < 40; i++) Text('row $i'),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  Future<_HostState> pump(
    WidgetTester t,
    List<Object?> closed, {
    Size size = const Size(400, 800),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: _Host(closed: closed)));
    await t.pumpAndSettle();
    return t.state<_HostState>(find.byType(_Host));
  }

  double sheetHeight(WidgetTester t) =>
      t.getSize(find.byKey(const ValueKey('map-sheet'))).height;

  testWidgets('the sheet peeks, rises for a pick and is never closed', (
    t,
  ) async {
    final closed = <Object?>[];
    final host = await pump(t, closed);
    expect(sheetHeight(t), moreOrLessEquals(80, epsilon: 1));
    expect(find.text('Title'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-sheet-close')), findsNothing);
    expect(t.takeException(), isNull); // a lowered sheet clips, never overflows

    host.pick();
    await t.pumpAndSettle();
    expect(sheetHeight(t), moreOrLessEquals(400, epsilon: 1));

    // Up to full: the map's top (the search bar) stays in view.
    await t.fling(find.text('Title'), const Offset(0, -300), 2000);
    await t.pumpAndSettle();
    expect(sheetHeight(t), moreOrLessEquals(700, epsilon: 1));

    // A hard fling down from full lands on half, then peek, never gone.
    await t.fling(find.text('Title'), const Offset(0, 300), 2000);
    await t.pumpAndSettle();
    await t.fling(find.text('Title'), const Offset(0, 300), 2000);
    await t.pumpAndSettle();
    await t.fling(find.text('Title'), const Offset(0, 300), 2000);
    await t.pumpAndSettle();
    expect(sheetHeight(t), moreOrLessEquals(80, epsilon: 1));
    expect(find.text('Title'), findsOneWidget);

    // The X goes back to the list.
    await t.tap(find.byKey(const ValueKey('map-sheet-close')));
    await t.pumpAndSettle();
    expect(closed, [null]);
    expect(find.byKey(const ValueKey('map-sheet-close')), findsNothing);
  });

  testWidgets('on a wide screen (a phone on its side) a pick opens it full', (
    t,
  ) async {
    final host = await pump(t, [], size: const Size(800, 400));
    host.pick();
    await t.pumpAndSettle();
    expect(sheetHeight(t), moreOrLessEquals(300, epsilon: 1)); // 400 - top 100
  });

  testWidgets("a content's done closes the sheet's pick, not the page", (
    t,
  ) async {
    final closed = <Object?>[];
    final host = await pump(t, closed);
    host.pick();
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(closed, ['saved']);
    expect(find.byType(_Host), findsOneWidget);
  });

  testWidgets('outside the map sheet, done pops as before', (t) async {
    Object? popped;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped = await Navigator.push<Object?>(
              context,
              MaterialPageRoute<Object?>(
                builder: (context) => TextButton(
                  onPressed: () => sheetCloser(context)('saved'),
                  child: const Text('Done'),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(popped, 'saved');
  });
}
