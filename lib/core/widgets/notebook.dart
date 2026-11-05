import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Left gutter (the margin) of a notebook page: marks sit in it, text starts after the red line.
const notebookGutter = 56.0;

/// A page with the red margin line down the left, on paper with a faint grain. Rows draw their own blue rules, so
/// they always line up.
class NotebookPage extends StatelessWidget {
  const NotebookPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _PaperGrainPainter(nb.ink)),
              ),
            ),
          ),
          // An exercise book's margin: a printed red line with a fainter one beside it.
          Positioned(
            left: notebookGutter - 8,
            top: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 1.5,
                    color: nb.margin.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 2.5),
                  Container(
                    width: 0.8,
                    color: nb.margin.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// One line of the notebook: a [mark] in the margin, the text on the line, a pale-blue rule under it.
class NotebookRow extends StatelessWidget {
  const NotebookRow({
    super.key,
    this.mark,
    required this.child,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
  });

  final Widget? mark;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: nb.rule)),
        ),
        padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: notebookGutter - 8,
              child: Center(child: mark),
            ),
            const SizedBox(width: 18),
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The page's title, handwritten, as on a notebook cover.
class NotebookTitle extends StatelessWidget {
  const NotebookTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.012, // written by hand: never quite level
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: Notebook.of(context).hand.copyWith(fontSize: 34, height: 1),
    ),
  );
}

/// Margin mark, drawn by pen: a filled pandan blob = on the map; a kunyit ring that does not quite close = no pin yet.
class PinMark extends StatelessWidget {
  const PinMark({super.key, required this.pinned});

  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return SizedBox.square(
      dimension: 14,
      child: CustomPaint(
        painter: _PenMarkPainter(
          filled: pinned,
          color: pinned ? nb.pandan : nb.kunyit,
        ),
      ),
    );
  }
}

// Fixed wobble (not random), so a mark looks the same on every frame and in every row.
const _wobble = [1.0, 0.93, 1.05, 0.96, 1.03, 0.92, 1.06, 0.97];

class _PenMarkPainter extends CustomPainter {
  const _PenMarkPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    if (filled) {
      // A dot pressed in with a pen: round, a little lumpy.
      final pts = [
        for (var i = 0; i < _wobble.length; i++)
          c +
              Offset.fromDirection(
                i * 2 * math.pi / _wobble.length,
                r * _wobble[i],
              ),
      ];
      final path = Path()
        ..moveTo((pts.last.dx + pts[0].dx) / 2, (pts.last.dy + pts[0].dy) / 2);
      for (var i = 0; i < pts.length; i++) {
        final next = pts[(i + 1) % pts.length];
        path.quadraticBezierTo(
          pts[i].dx,
          pts[i].dy,
          (pts[i].dx + next.dx) / 2,
          (pts[i].dy + next.dy) / 2,
        );
      }
      canvas.drawPath(path, Paint()..color = color);
      return;
    }
    // A ring drawn in one stroke: it starts top-left, goes round a bit past where it began and drifts outward.
    final path = Path();
    const start = -2.1, sweep = 2 * math.pi + 0.55, steps = 40;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = start + sweep * t;
      final rr = r * (1 + 0.05 * math.sin(3 * a + 1) + 0.12 * t * t);
      final p = c + Offset.fromDirection(a, rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PenMarkPainter old) =>
      old.filled != filled || old.color != color;
}

/// Faint specks of paper fibre; a fixed seed, so the page does not shimmer on repaint.
class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final n = math.min(2500, (size.width * size.height / 700).round());
    final points = [
      for (var i = 0; i < n; i++)
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = ink.withValues(alpha: 0.035)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PaperGrainPainter old) => old.ink != ink;
}

/// A bottom sheet as a notebook page: paper, the red margin line, ruled rows inside.
Future<T?> showNotebookSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final nb = Notebook.of(context);
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: nb.paper,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      side: BorderSide(color: nb.line),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: NotebookPage(child: builder(context)),
      ),
    ),
  );
}

/// One button of an [ActionDock]. No [onPressed] = shown, but off.
class DockAction {
  const DockAction({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.danger = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool danger;
  final bool busy;
}

/// A page's actions on a slip of paper floating at the bottom, always in reach. Use as the Scaffold's
/// bottomNavigationBar with `extendBody: true`, and pad the page's list by [ActionDock.clearance].
class ActionDock extends StatelessWidget {
  const ActionDock({super.key, required this.actions});

  final List<DockAction> actions;

  static const clearance = 104.0;

  /// Room a docked page needs under its content, read from a context INSIDE the Scaffold body: the dock, and the
  /// keyboard while it is open. With `extendBody` the body runs under both; the Scaffold reports them as the body's
  /// bottom padding. Use it for the list's bottom padding and a text field's `scrollPadding`, so a focused field
  /// scrolls up above the dock instead of staying behind the keyboard.
  static double bottomRoom(BuildContext context) =>
      math.max(clearance, MediaQuery.paddingOf(context).bottom + 20);

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    // A Scaffold's bottom bar stays under the keyboard: lift the dock above it.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: nb.paper,
          elevation: 3,
          shadowColor: nb.ink.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: nb.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              for (final a in actions) Expanded(child: _DockButton(action: a)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.action});

  final DockAction action;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final a = action;
    final on = a.onPressed != null && !a.busy;
    final color = !on
        ? nb.inkSoft.withValues(alpha: 0.45)
        : a.danger
        ? nb.margin
        : nb.pandanDeep;
    return Tooltip(
      message: a.tooltip ?? a.label,
      child: InkWell(
        onTap: on ? a.onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 24,
                child: a.busy
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: nb.pandan,
                        ),
                      )
                    : Icon(a.icon, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                a.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice in a [NotebookSegmented].
class NotebookSegment<T> {
  const NotebookSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Notebook-style segmented control: a row of labels, with a hand-drawn ink underline under the active one.
/// Use for two or a few mutually exclusive views (Open/Closed, Just me/Everyone). On a change the line is written
/// under the new label with a pen, left to right, then a fainter return stroke (no slide; instant with reduced motion).
class NotebookSegmented<T> extends StatefulWidget {
  const NotebookSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<NotebookSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<NotebookSegmented<T>> createState() => _NotebookSegmentedState<T>();
}

class _NotebookSegmentedState<T> extends State<NotebookSegmented<T>>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  // 0 = nothing written yet, 1 = the underline done. Starts done: a page opens with its underline already there.
  late final _pen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  late final _stroke = CurvedAnimation(parent: _pen, curve: Curves.easeInOut);
  bool _writeNext = false;
  late List<GlobalKey> _keys;
  double? _left;
  double? _top;
  double? _width;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.segments.length, (_) => GlobalKey());
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _stroke.dispose();
    _pen.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotebookSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length) {
      _keys = List.generate(widget.segments.length, (_) => GlobalKey());
      _left = null;
      _top = null;
      _width = null;
    }
    if (oldWidget.selected != widget.selected) {
      // Lift the pen now, so the old underline is not seen for a frame before the new one is written.
      _pen.value = 0;
      _writeNext = true;
    }
    if (oldWidget.selected != widget.selected ||
        oldWidget.segments != widget.segments) {
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final index = widget.segments.indexWhere(
      (segment) => segment.value == widget.selected,
    );
    if (stack == null || index < 0 || index >= _keys.length) return;
    final label = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    if (label == null) return;
    if (_writeNext) {
      _writeNext = false;
      if (MediaQuery.disableAnimationsOf(context)) {
        _pen.value = 1;
      } else {
        _pen.forward(from: 0);
      }
    }
    final offset = label.localToGlobal(Offset.zero, ancestor: stack);
    final left = offset.dx - 1;
    final top = offset.dy + label.size.height - 1;
    final width = label.size.width + 2;
    if (_left == left && _top == top && _width == width) return;
    setState(() {
      _left = left;
      _top = top;
      _width = width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Wrap(
          spacing: 4,
          children: [
            for (var i = 0; i < widget.segments.length; i++)
              _segment(widget.segments[i], i, nb, text),
          ],
        ),
        if (_left case final left? when _top != null && _width != null)
          Positioned(
            left: left,
            top: _top!,
            width: _width!,
            height: 7,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _InkUnderlinePainter(nb.pandanDeep, progress: _stroke),
              ),
            ),
          ),
      ],
    );
  }

  Widget _segment(
    NotebookSegment<T> segment,
    int index,
    Notebook nb,
    TextTheme text,
  ) {
    final active = segment.value == widget.selected;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => widget.onChanged(segment.value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Text(
            segment.label,
            key: _keys[index],
            style: text.labelLarge?.copyWith(
              color: active ? nb.ink : nb.inkSoft,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A pen underline: one stroke left to right that lifts at the end, then a fainter return stroke under it.
/// The nib presses harder mid-stroke (thicker) and lightly at both ends. [progress] writes it over time.
class _InkUnderlinePainter extends CustomPainter {
  _InkUnderlinePainter(this.color, {this.progress}) : super(repaint: progress);

  final Color color;
  final Animation<double>? progress;

  // The main stroke takes this share of the time, then the pen lifts briefly before the return stroke.
  static const _mainEnds = 0.68, _returnStarts = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = progress?.value ?? 1;

    final main = Path()
      ..moveTo(0, h * 0.62)
      ..cubicTo(w * 0.22, h * 0.38, w * 0.52, h * 0.66, w * 0.78, h * 0.44)
      ..quadraticBezierTo(
        w * 0.93,
        h * 0.32,
        w,
        h * 0.16,
      ); // a small flick up as the pen lifts
    _write(canvas, main, (p / _mainEnds).clamp(0, 1), color, 2.4);

    final back = Path()
      ..moveTo(w * 0.95, h * 0.66)
      ..cubicTo(w * 0.7, h * 0.88, w * 0.36, h * 0.68, w * 0.07, h * 0.86);
    final q = ((p - _returnStarts) / (1 - _returnStarts)).clamp(0.0, 1.0);
    _write(canvas, back, q, color.withValues(alpha: color.a * 0.5), 1.4);
  }

  /// Draws the first [upTo] (0..1) of [path] in short pieces, each as thick as the pen presses at that point.
  static void _write(
    Canvas canvas,
    Path path,
    double upTo,
    Color color,
    double width,
  ) {
    if (upTo <= 0) return;
    // Pieces overlap at their round ends: drawn solid inside one see-through layer, or a pale line looks beaded.
    canvas.saveLayer(
      path.getBounds().inflate(width),
      Paint()..color = Color.fromRGBO(0, 0, 0, color.a),
    );
    final ink = Paint()
      ..color = color.withValues(alpha: 1)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const pieces = 28;
    for (final m in path.computeMetrics()) {
      final end = m.length * upTo;
      for (var i = 0; i < pieces; i++) {
        final a = m.length * i / pieces;
        if (a >= end) break;
        final b = math.min(end, m.length * (i + 1) / pieces);
        final t = (a + b) / 2 / m.length;
        ink.strokeWidth = width * (0.45 + 0.55 * math.sin(math.pi * t));
        canvas.drawPath(m.extractPath(a, b), ink);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkUnderlinePainter old) =>
      old.color != color || old.progress != progress;
}

/// A heading on the page, after the margin line: written by hand and underlined with the pen.
class NotebookHeading extends StatelessWidget {
  const NotebookHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 24, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          header: true,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text,
                  style: nb.hand.copyWith(
                    fontSize: 26,
                    height: 1.05,
                    color: nb.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: 7,
                  child: CustomPaint(
                    painter: _InkUnderlinePainter(
                      nb.pandanDeep.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
