import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's "deleting" overlay: blocks taps and loops a sheet of paper being crumpled and thrown into a bin, with
/// [label] under it (e.g. "Deleting 3 of 10"). Put it on top of the page in a Stack while a delete runs.
class DeletingOverlay extends StatelessWidget {
  const DeletingOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(dismissible: false, color: nb.ink.withValues(alpha: 0.35)),
        Center(
          child: Material(
            color: nb.paper,
            elevation: 6,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DeletingAnimation(),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The loop alone: paper crumples into a ball, flies into the bin, the lid shuts. A still frame when the phone asks
/// for reduced motion.
class DeletingAnimation extends StatefulWidget {
  const DeletingAnimation({super.key, this.width = 140});

  final double width;

  @override
  State<DeletingAnimation> createState() => _DeletingAnimationState();
}

class _DeletingAnimationState extends State<DeletingAnimation>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop
        ..stop()
        ..value = 0.55; // mid-flight: still reads as "into the bin"
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.width * 0.8,
        child: CustomPaint(painter: _TrashPainter(_loop, nb)),
      ),
    );
  }
}

class _TrashPainter extends CustomPainter {
  _TrashPainter(this.t, this.nb) : super(repaint: t);

  final Animation<double> t;
  final Notebook nb;

  // Crumpled ball's outline: a jagged circle, radius per point.
  static const _jag = [
    1.0,
    .78,
    .96,
    .82,
    1.0,
    .74,
    .92,
    .86,
    .98,
    .76,
    .9,
    .84,
  ];
  static const _start = Offset(34, 42); // the sheet's centre (120 × 96 space)
  static const _mouth = Offset(88, 50); // above the bin
  static const _binTop = 58.0;

  static double _span(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    canvas.scale(size.width / 120, size.height / 96);

    // a short hold on the plain sheet first, so it reads as "a page" before it is crushed
    final crumple = Curves.easeInOutCubic.transform(_span(v, .14, .36));
    final fly = Curves.easeInOut.transform(_span(v, .36, .74));
    final drop = Curves.easeIn.transform(_span(v, .74, .86));
    final appear = _span(v, 0, .06);
    final lid =
        Curves.easeOut.transform(_span(v, .3, .5)) -
        Curves.easeIn.transform(_span(v, .86, .96));
    final bounce = math.sin(_span(v, .86, 1) * math.pi) * 1.5;

    // The paper / ball (drawn first: the bin's front hides it once it drops in).
    if (drop < 1) {
      final c = Offset(
        _start.dx + (_mouth.dx - _start.dx) * fly,
        _start.dy +
            (_mouth.dy - _start.dy) * fly -
            math.sin(fly * math.pi) * 30 +
            (_binTop + 16 - _mouth.dy) * drop,
      );
      final spin = fly * math.pi * 2.5;
      _paper(canvas, c, crumple, spin, appear);
    }

    // The bin.
    final ink = Paint()
      ..color = nb.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(0, bounce);
    final body = Path()
      ..moveTo(72, _binTop)
      ..lineTo(104, _binTop)
      ..lineTo(100, 90)
      ..lineTo(76, 90)
      ..close();
    canvas.drawPath(body, Paint()..color = nb.mist);
    canvas.drawPath(body, ink);
    for (final x in [82.0, 88.0, 94.0]) {
      canvas.drawLine(Offset(x, _binTop + 7), Offset(x, 84), ink);
    }
    // The lid swings up about its right end.
    canvas.translate(106, _binTop - 2);
    canvas.rotate(1.0 * lid); // positive = the free (left) end goes up
    final lidRect = RRect.fromLTRBR(-37, -3, 0, 2, const Radius.circular(2));
    canvas.drawRRect(lidRect, Paint()..color = nb.mist);
    canvas.drawRRect(lidRect, ink);
    canvas.drawLine(const Offset(-22, -6), const Offset(-15, -6), ink);
    canvas.restore();
  }

  /// A sheet ([k] 0) morphing into a crumpled ball ([k] 1) at [c].
  void _paper(Canvas canvas, Offset c, double k, double spin, double alpha) {
    const w = 15.0, h = 19.0, ball = 9.0;
    final path = Path();
    // The sheet's outline: its 4 corners and 2 points on each edge, clockwise from the top left (a sharp rectangle).
    const corners = [
      Offset(-w, -h),
      Offset(w, -h),
      Offset(w, h),
      Offset(-w, h),
    ];
    for (var i = 0; i < _jag.length; i++) {
      final from = corners[i ~/ 3], to = corners[(i ~/ 3 + 1) % 4];
      final sheet = Offset.lerp(from, to, (i % 3) / 3)!;
      // the ball's point in the same direction, so each point travels straight inwards
      final ballPoint = sheet / sheet.distance * ball * _jag[i];
      final p = Offset.lerp(sheet, ballPoint, k)!;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin + k * .6);
    canvas.drawPath(path, Paint()..color = nb.paper.withValues(alpha: alpha));
    final edge = Paint()
      ..color = nb.ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, edge);
    // Ruled lines fade as it crumples; creases show instead.
    final lines = Paint()
      ..color = nb.rule.withValues(alpha: alpha * (1 - k))
      ..strokeWidth = 1.4;
    for (final y in [-9.0, -3.0, 3.0, 9.0]) {
      canvas.drawLine(Offset(-10 * (1 - k), y), Offset(10 * (1 - k), y), lines);
    }
    if (k > .5) {
      final crease = Paint()
        ..color = nb.inkSoft.withValues(alpha: alpha * (k - .5) * 2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawPath(
        Path()
          ..moveTo(-5, -3)
          ..lineTo(0, 1)
          ..lineTo(4, -4)
          ..moveTo(-3, 5)
          ..lineTo(2, 3),
        crease,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashPainter old) => old.nb != nb;
}
