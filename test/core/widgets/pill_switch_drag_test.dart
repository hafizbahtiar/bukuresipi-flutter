import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/core/widgets/pill_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'without pages (Settings), dragging the chip picks the option it lands on',
    (t) async {
      var value = 'light';
      final changed = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [Notebook.light]),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => PillSwitch<String>(
                  key: const ValueKey('pill'),
                  value: value,
                  onChanged: (v) => setState(() {
                    value = v;
                    changed.add(v);
                  }),
                  options: const [
                    ('light', Text('Light'), null),
                    ('dark', Text('Dark'), null),
                    ('system', Text('System'), null),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final light = t.getCenter(find.text('Light'));
      final system = t.getCenter(find.text('System'));

      // Slowly from Light to System: nothing picked mid-drag, System on release.
      final g = await t.startGesture(light);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset((system.dx - light.dx) / 10, 0));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(changed, isEmpty);
      await g.up();
      await t.pumpAndSettle();
      expect(changed, ['system']);

      // A tap still works.
      await t.tap(find.text('Dark'));
      await t.pumpAndSettle();
      expect(changed, ['system', 'dark']);
    },
  );

  testWidgets(
    'released, the chip goes straight to the new option while the parent is still saving it',
    (t) async {
      var value = 'light';
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [Notebook.light]),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => PillSwitch<String>(
                  value: value,
                  // Like the theme setting: the new value comes back a little later.
                  onChanged: (v) => Future<void>.delayed(
                    const Duration(milliseconds: 150),
                    () => setState(() => value = v),
                  ),
                  options: const [
                    ('light', Text('Light'), null),
                    ('dark', Text('Dark'), null),
                    ('system', Text('System'), null),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      // The chip: the pill's DecoratedBox with a shadow.
      double chipX() => t
          .getCenter(
            find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).boxShadow != null,
            ),
          )
          .dx;
      final light = t.getCenter(find.text('Light')).dx;
      final system = t.getCenter(find.text('System')).dx;
      final g = await t.startGesture(t.getCenter(find.text('Light')));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset((system - light) / 10, 0));
        await t.pump(const Duration(milliseconds: 30));
      }
      await g.up();
      // Every frame until the parent answers and after: never back towards Light.
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(chipX(), greaterThan(system - 30));
      }
      await t.pumpAndSettle();
      expect(value, 'system');
      expect(chipX(), closeTo(system, 30));
    },
  );
}
