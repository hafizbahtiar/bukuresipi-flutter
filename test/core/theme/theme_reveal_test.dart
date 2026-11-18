import 'package:bukuresipi_flutter/core/theme/theme_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app whose theme [dark] flips through the reveal.
class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => ThemeReveal(child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ThemeReveal.maybeOf(context)!.change(
              const Offset(100, 100),
              () => setState(() => dark = !dark),
            ),
            child: const Text('switch'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the old look covers the screen, a circle opens it, then it goes',
    (t) async {
      await t.pumpWidget(const _App());
      // The picture is taken off the fake clock.
      await t.runAsync(() async {
        await t.tap(find.text('switch'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pump();
      expect(
        t.state<_AppState>(find.byType(_App)).dark,
        isTrue,
      ); // switched at once, under the picture
      expect(find.byKey(const ValueKey('theme-reveal')), findsOneWidget);
      await t.pump(ThemeReveal.duration ~/ 2);
      expect(find.byKey(const ValueKey('theme-reveal')), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('theme-reveal')), findsNothing);
    },
  );

  testWidgets('with reduced motion it just switches', (t) async {
    await t.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: _App(),
      ),
    );
    await t.tap(find.text('switch'));
    await t.pump();
    expect(t.state<_AppState>(find.byType(_App)).dark, isTrue);
    expect(find.byKey(const ValueKey('theme-reveal')), findsNothing);
  });

  testWidgets(
    'a second change starts with the circle closed: no frame of the new theme first',
    (t) async {
      await t.pumpWidget(const _App());
      double circle() {
        final paint = t.widget<CustomPaint>(
          find.byKey(const ValueKey('theme-reveal')),
        );
        return ((paint.painter! as dynamic).t as Animation<double>).value;
      }

      for (var round = 0; round < 2; round++) {
        await t.runAsync(() async {
          await t.tap(find.text('switch'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await t.pump(); // the first frame with the old picture up
        expect(circle(), 0, reason: 'round $round');
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('theme-reveal')), findsNothing);
      }
    },
  );
}
