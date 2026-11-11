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
Future<({List<int> picked, List<int> adds})> _pump(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
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
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNav(
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

double _chipX(WidgetTester t) =>
    t.getCenter(find.byKey(const ValueKey('nav-chip'))).dx;

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
}
