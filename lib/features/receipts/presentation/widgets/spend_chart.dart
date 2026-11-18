import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';

/// The last 12 months as bars: rounded pandan bars on a light grid, a month with no spend a short stub, the current
/// Malaysia month in the deeper green, and the largest month's ringgit at the top left. No dependency: one painter.
/// New amounts morph: each bar grows or shrinks from its old height, and the scale (and its ringgit) with it.
class SpendChart extends StatefulWidget {
  const SpendChart({super.key, required this.months});

  /// 'YYYY-MM' with visits only; a month with none is left out (drawn as an empty stub).
  final List<({String month, int visits, int totalSen})> months;

  @override
  State<SpendChart> createState() => _SpendChartState();
}

class _SpendChartState extends State<SpendChart>
    with SingleTickerProviderStateMixin {
  late final _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  /// What was drawn before the last change (the morph's start).
  List<int>? _fromValues;
  int _fromTop = 0;
  List<int> _values = const [];
  int _top = 0;

  @override
  void didUpdateWidget(SpendChart old) {
    super.didUpdateWidget(old);
    if (old.months == widget.months) return;
    _fromValues = _values;
    _fromTop = _top;
    if (MediaQuery.disableAnimationsOf(context)) {
      _morph.value = 1;
    } else {
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final nb = Notebook.of(context);
    final now = DateTime.now();
    final last = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    String key(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final byMonth = {for (final m in months) m.month: m.totalSen};
    final top = byMonth.values.fold(0, (a, b) => a > b ? a : b);
    final locale = Localizations.localeOf(context).toString();
    final values = [for (final m in last) byMonth[key(m)] ?? 0];
    _values = values;
    _top = top;
    final from = _fromValues;
    return SizedBox(
      key: const ValueKey('spend-chart'),
      height: 132,
      child: CustomPaint(
        painter: _SpendPainter(
          t: CurvedAnimation(parent: _morph, curve: Curves.easeInOutCubic),
          nb: nb,
          fromValues: from != null && from.length == values.length
              ? from
              : values,
          fromTop: from == null ? top : _fromTop,
          values: values,
          labels: [for (final m in last) DateFormat.MMM(locale).format(m)],
          current: last.length - 1,
          top: top,
          textScaler: MediaQuery.textScalerOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SpendPainter extends CustomPainter {
  _SpendPainter({
    required this.t,
    required this.fromValues,
    required this.fromTop,
    required this.nb,
    required this.values,
    required this.labels,
    required this.current,
    required this.top,
    required this.textScaler,
  }) : super(repaint: t);

  final Animation<double> t;
  final List<int> fromValues;
  final int fromTop;
  final Notebook nb;
  final List<int> values;
  final List<String> labels;
  final int current;
  final int top;
  final TextScaler textScaler;

  static const _labelHeight = 18.0;
  static const _topPad = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final k = t.value;
    double lerp(num a, num b) => a + (b - a) * k;
    final bottom = size.height - _labelHeight;
    final plot = bottom - _topPad;
    final shownTop = lerp(fromTop, top);
    final max = shownTop <= 0 ? 1.0 : shownTop;
    final grid = Paint()
      ..color = nb.line
      ..strokeWidth = 1;
    for (final part in const [0.0, 0.5, 1.0]) {
      final y = bottom - plot * part;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _label(
      canvas,
      'RM ${(shownTop / 100).round()}',
      const Offset(0, 0),
      nb.inkSoft,
      FontWeight.w500,
    );
    final slot = size.width / values.length;
    final barWidth = (slot * 0.62).clamp(2.0, 22.0);
    for (var i = 0; i < values.length; i++) {
      final value = lerp(fromValues[i], values[i]);
      final height = value <= 0 ? 2.0 : 2 + (plot - 2) * value / max;
      final left = slot * i + (slot - barWidth) / 2;
      final paint = Paint()
        ..color = value <= 0
            ? nb.line
            : (i == current ? nb.pandanDeep : nb.pandan);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, bottom - height, barWidth, height),
          const Radius.circular(2),
        ),
        paint,
      );
      final label = _text(
        labels[i],
        i == current ? nb.ink : nb.inkSoft,
        i == current ? FontWeight.w700 : FontWeight.w400,
      );
      label.paint(
        canvas,
        Offset(slot * i + (slot - label.width) / 2, bottom + 4),
      );
    }
  }

  TextPainter _text(String text, Color color, FontWeight weight) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: 9, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    FontWeight weight,
  ) {
    _text(text, color, weight).paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SpendPainter old) =>
      old.top != top ||
      old.fromTop != fromTop ||
      !_same(old.fromValues, fromValues) ||
      old.current != current ||
      old.nb != nb ||
      old.textScaler != textScaler ||
      !_same(old.values, values) ||
      !_same(old.labels, labels);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
