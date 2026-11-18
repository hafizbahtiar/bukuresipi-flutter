import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('a plain bottom sheet shows the drag handle ($name)', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SizedBox(height: 120, child: Text('Camera')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
      // Material's handle widget is private: found by its type's name.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_DragHandle',
        ),
        findsOneWidget,
      );
    });
  }
}
