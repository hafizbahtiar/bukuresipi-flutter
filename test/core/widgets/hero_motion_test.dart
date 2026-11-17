import 'package:bukuresipi_flutter/core/widgets/hero_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a photo flies straight and eased over the whole transition', () {
    const from = Rect.fromLTWH(0, 0, 100, 100);
    const to = Rect.fromLTWH(200, 400, 300, 300);
    final flight = heroFlight()(from, to);

    expect(flight.transform(0), from);
    expect(flight.transform(1), to);
    expect(
      flight.transform(0.5),
      Rect.lerp(from, to, Curves.easeInOutCubic.transform(0.5)),
    );
    // Eased: slower than linear at the start and the end.
    expect(
      flight.transform(0.1)!.left,
      lessThan(Rect.lerp(from, to, 0.1)!.left),
    );
    expect(
      flight.transform(0.9)!.left,
      greaterThan(Rect.lerp(from, to, 0.9)!.left),
    );
    // Straight: every centre on the line between the two (no arc).
    for (final t in [0.1, 0.3, 0.6, 0.8]) {
      final c = flight.transform(t)!.center;
      final along = (c.dx - from.center.dx) / (to.center.dx - from.center.dx);
      expect(
        c.dy,
        closeTo(from.center.dy + along * (to.center.dy - from.center.dy), 1e-9),
      );
    }

    // The shuttle's corner morph follows the same pace.
    final page = AnimationController(vsync: const TestVSync(), value: 0.3);
    expect(
      heroPace(page).value,
      closeTo(Curves.easeInOutCubic.transform(0.3), 1e-9),
    );
    page.dispose();
  });
}
