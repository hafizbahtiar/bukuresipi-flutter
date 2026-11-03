import 'package:bukuresipi_flutter/core/router/book_page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a flip starts flat, curls into a half roll midway, and ends turned over past the spine', () {
    const size = Size(360, 640);
    final flat = PageFlip(size, 0);
    expect(flat.edge, size.width);
    expect(
      flat.land(const Offset(360, 640)),
      offsetMoreOrLessEquals(const Offset(360, 640)),
    );
    // Midway the free edge has curled right over to the spine.
    expect(PageFlip(size, 0.5).land(const Offset(360, 320)).dx, lessThan(1));
    expect(PageFlip(size, 1).edge, moreOrLessEquals(0));
    for (var i = 1; i <= 20; i++) {
      expect(
        PageFlip(size, i / 20).edge,
        lessThanOrEqualTo(PageFlip(size, (i - 1) / 20).edge + 0.001),
      );
    }
  });

  testWidgets(
    'forward lifts the old page, reveals the new one, and keeps its state',
    (tester) async {
      var inits = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: BookPageTransitionsBuilder()},
            ),
          ),
          home: const Text('old'),
        ),
      );

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => _Counted(onInit: () => inits++),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final turn = tester.widget<SnapshotWidget>(
        find
            .ancestor(
              of: find.text('old'),
              matching: find.byType(SnapshotWidget),
            )
            .first,
      );
      expect(
        turn.controller.allowSnapshotting,
        isTrue,
        reason: 'the old page flips away as a snapshot',
      );

      await tester.pumpAndSettle();
      expect(inits, 1);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(inits, 1);
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
    },
  );
}

class _Counted extends StatefulWidget {
  const _Counted({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Text('new');
}
