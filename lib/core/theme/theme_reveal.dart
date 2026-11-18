import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A theme change as a growing circle: [change] takes a picture of the screen in the old theme, switches the theme
/// underneath, then opens a circle through the picture from where the user tapped, so the new theme spreads from
/// their finger. Wrap the app once (MaterialApp's builder). Instant with reduced motion.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});

  final Widget child;

  static const duration = Duration(milliseconds: 600);

  /// The reveal above [context]; null when the app is not wrapped (tests, previews).
  static ThemeRevealState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ThemeRevealState>();

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  ui.Image? _old;
  Offset _origin = Offset.zero;

  late final _grow =
      AnimationController(vsync: this, duration: ThemeReveal.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _drop();
        });
  late final _curve = CurvedAnimation(
    parent: _grow,
    curve: Curves.easeInOutCubic,
  );

  /// Runs [apply] (the theme switch) behind a circle growing from [origin] (global position).
  Future<void> change(Offset origin, FutureOr<void> Function() apply) async {
    final box =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (MediaQuery.disableAnimationsOf(context) ||
        _old != null || // one at a time: a second tap mid-reveal just switches
        box == null ||
        !box.hasSize) {
      await apply();
      return;
    }
    final ui.Image picture;
    try {
      // At most 2x: the old look only shows while it shrinks away, and a 3.5x phone's full picture is ~4x the
      // memory of a 2x one for no visible gain.
      picture = await box.toImage(
        pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 2.0),
      );
    } catch (_) {
      await apply(); // no picture (e.g. a platform view): switch without the circle
      return;
    }
    if (!mounted) {
      picture.dispose();
      return;
    }
    // The picture covers the screen in the same frame the theme changes under it: no flash of either. The last
    // reveal left the circle fully open: closed now, or that first frame would show the new theme everywhere.
    _grow.value = 0;
    setState(() {
      _old = picture;
      _origin = origin;
    });
    await apply();
    // Start the clock after the frame that rebuilds the app in the new theme (the one heavy frame), so the circle's
    // first steps are not spent inside it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_grow.forward());
    });
  }

  void _drop() {
    final old = _old;
    if (old == null) return;
    setState(() => _old = null);
    old.dispose();
  }

  @override
  void dispose() {
    _grow.dispose();
    _old?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (old != null)
          Positioned.fill(
            child: IgnorePointer(
              // Its own layer, repainted by the animation alone: no widget rebuilds per frame, and the app under
              // it (already in the new theme) is not repainted.
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('theme-reveal'),
                  painter: _OldLook(old, _origin, _curve),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The old look, everywhere but a circle at [center] that grows, as [t] goes 0..1, to the farthest corner.
class _OldLook extends CustomPainter {
  _OldLook(this.image, this.center, this.t) : super(repaint: t);

  final ui.Image image;
  final Offset center;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - center).distance).reduce(math.max);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: center, radius: far * t.value)),
    );
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OldLook old) =>
      old.image != image || old.center != center || old.t != t;
}
