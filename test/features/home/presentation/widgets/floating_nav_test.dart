import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/features/home/presentation/widgets/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  NavItem(Icons.home_outlined, Icons.home, 'Home'),
  NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Book'),
  NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Receipts'),
  NavItem(Icons.person_outline, Icons.person, 'Account'),
];

/// The bar at 400 dp: 5 slots of ~74 dp (Home, Book, +, Receipts, Account).
Future<({List<int> picked, List<int> adds})> _pump(
  WidgetTester t, {
  bool vertical = false,
}) async {
  t.view.physicalSize = vertical ? const Size(800, 400) : const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final picked = <int>[];
  final adds = <int>[];
  var selected = 0;
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [Notebook.light]),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          extendBody: true,
          body: vertical
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: FloatingNav(
                    vertical: true,
                    items: _items,
                    selected: selected,
                    onSelected: (i) => setState(() {
                      selected = i;
                      picked.add(i);
                    }),
                    addLabel: 'Add',
                    onAdd: () => adds.add(1),
                  ),
                )
              : const SizedBox.expand(),
          bottomNavigationBar: vertical
              ? null
              : FloatingNav(
                  items: _items,
                  selected: selected,
                  onSelected: (i) => setState(() {
                    selected = i;
                    picked.add(i);
                  }),
                  addLabel: 'Add',
                  onAdd: () => adds.add(1),
                ),
        ),
      ),
    ),
  );
  return (picked: picked, adds: adds);
}

/// The chip as drawn (it is painted, not a widget of its own).
Rect _chip(WidgetTester t) {
  final f = find.byKey(const ValueKey('nav-chip'));
  return navChipRect(
    t.widget<CustomPaint>(f).painter!,
    t.getSize(f),
  ).shift(t.getTopLeft(f));
}

double _chipX(WidgetTester t) => _chip(t).center.dx;

void main() {
  testWidgets(
    'icons only, names as tooltips; a tap picks a tab, "+" is not a tab',
    (t) async {
      final r = await _pump(t);
      expect(find.text('Book'), findsNothing);
      expect(find.byTooltip('Book'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nav-tab-2')));
      await t.pumpAndSettle();
      expect(r.picked, [2]);
      expect(
        _chipX(t),
        closeTo(t.getCenter(find.byKey(const ValueKey('nav-tab-2'))).dx, 1),
      );
      await t.tap(find.byKey(const ValueKey('nav-add')));
      expect(r.adds, [1]);
      expect(r.picked, [2]);
      // The open tab tapped again is reported too (Home scrolls back to the top).
      await t.tap(find.byKey(const ValueKey('nav-tab-2')));
      expect(r.picked, [2, 2]);
    },
  );

  testWidgets(
    'the chip follows a drag and settles on the nearest tab, skipping "+"',
    (t) async {
      final r = await _pump(t);
      final home = t.getCenter(find.byKey(const ValueKey('nav-tab-0')));
      final g = await t.startGesture(home);
      await g.moveBy(const Offset(40, 0));
      await t.pump();
      await g.moveBy(const Offset(40, 0));
      await t.pump();
      // Its ends chase the finger on their springs, and catch up while it holds still.
      await t.pump(const Duration(milliseconds: 600));
      expect(_chipX(t), closeTo(home.dx + 80, 2)); // under the finger
      expect(r.picked, isEmpty); // nothing switches until the finger lifts
      // Slowly on to "+" (slot 2): it is not a tab, so the chip settles on a neighbour.
      await g.moveBy(const Offset(70, 0));
      await t.pump(const Duration(seconds: 1));
      await g.up();
      await t.pumpAndSettle();
      expect(r.picked.single, anyOf(1, 2)); // Book or Receipts, never "+"
    },
  );

  testWidgets(
    'while dragged, the chip moves with the finger frame by frame, before it lifts',
    (t) async {
      await _pump(t);
      final home = t.getCenter(find.byKey(const ValueKey('nav-tab-0')));
      final rest = _chipX(t);
      final g = await t.startGesture(home);
      // A finger moving every frame, as on a phone: 8 dp a frame for 10 frames.
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(8, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(
        _chipX(t) - rest,
        greaterThan(50),
      ); // most of the 80 dp already, the finger still down
      await g.up();
      await t.pumpAndSettle();
    },
  );

  testWidgets(
    'the chip flows like water: it stretches and thins towards the tab, then lands as one tab',
    (t) async {
      await _pump(t);
      Size chip() => _chip(t).size;
      final rest = chip();
      // Home -> Account: 4 slots on.
      await t.tap(find.byKey(const ValueKey('nav-tab-3')));
      var longest = rest.width, thinnest = rest.height;
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 16));
        if (chip().width > longest) longest = chip().width;
        if (chip().height < thinnest) thinnest = chip().height;
      }
      expect(longest, greaterThan(rest.width * 1.3)); // the front end leads
      expect(thinnest, lessThan(rest.height * 0.95)); // stretched, it thins
      await t.pumpAndSettle();
      expect(chip().width, closeTo(rest.width, 0.5));
      expect(chip().height, closeTo(rest.height, 0.5));
      expect(
        _chipX(t),
        closeTo(t.getCenter(find.byKey(const ValueKey('nav-tab-3'))).dx, 1),
      );
    },
  );

  testWidgets(
    'only the chip drags: a drag from another tab or "+" moves nothing',
    (t) async {
      final r = await _pump(t);
      final rest = _chipX(t);
      for (final key in ['nav-tab-1', 'nav-tab-3']) {
        final g = await t.startGesture(t.getCenter(find.byKey(ValueKey(key))));
        await g.moveBy(const Offset(-60, 0));
        await t.pump();
        expect(_chipX(t), closeTo(rest, 1), reason: key); // the chip stays put
        await g.up();
        await t.pumpAndSettle();
      }
      expect(r.picked, isEmpty);
      // A tap still switches tabs.
      await t.tap(find.byKey(const ValueKey('nav-tab-1')));
      await t.pumpAndSettle();
      expect(r.picked, [1]);
    },
  );

  testWidgets('a flick goes on to the next tab in its direction', (t) async {
    final r = await _pump(t);
    await t.fling(
      find.byKey(const ValueKey('nav-tab-0')),
      const Offset(50, 0),
      1000,
    );
    await t.pumpAndSettle();
    expect(r.picked, [1]);
    // From Book a flick right passes "+" to Receipts (a slow release there would settle back on Book).
    await t.fling(
      find.byKey(const ValueKey('nav-tab-1')),
      const Offset(50, 0),
      1000,
    );
    await t.pumpAndSettle();
    expect(r.picked, [1, 2]);
  });

  testWidgets(
    'a tab with a picture (the avatar) shows it instead of its icons',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [Notebook.light]),
          home: Scaffold(
            bottomNavigationBar: FloatingNav(
              items: [
                ..._items.take(3),
                const NavItem(
                  Icons.person_outline,
                  Icons.person,
                  'Account',
                  picture: CircleAvatar(key: ValueKey('me')),
                ),
              ],
              selected: 3,
              onSelected: (_) {},
              addLabel: 'Add',
              onAdd: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('me')), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsNothing);
      expect(find.byTooltip('Account'), findsOneWidget);
    },
  );

  testWidgets('standing (a rail): a tap picks, the chip drags down to a tab', (
    t,
  ) async {
    final r = await _pump(t, vertical: true);
    expect(t.takeException(), isNull);
    double y(String key) => t.getCenter(find.byKey(ValueKey(key))).dy;
    expect(y('nav-tab-1'), greaterThan(y('nav-tab-0')));
    expect(y('nav-add'), greaterThan(y('nav-tab-1')));
    await t.tap(find.byKey(const ValueKey('nav-tab-2')));
    await t.pumpAndSettle();
    expect(r.picked, [2]);
    // From tab 2 one slot down = tab 3.
    await t.drag(find.byKey(const ValueKey('nav-tab-2')), const Offset(0, 56));
    await t.pumpAndSettle();
    expect(r.picked, [2, 3]);
    expect(_chip(t).center.dy, closeTo(y('nav-tab-3'), 1));
    await t.tap(find.byKey(const ValueKey('nav-add')));
    expect(r.adds, [1]);
  });
}
