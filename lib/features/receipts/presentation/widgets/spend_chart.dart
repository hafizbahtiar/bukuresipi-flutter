import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';

/// The last 12 months as bars: rounded pandan bars on a light grid, a month with no spend a short stub, the current
/// Malaysia month in the deeper green, and the largest month's ringgit at the top left. No dependency: one painter.
class SpendChart extends StatelessWidget {
  const SpendChart({super.key, required this.months});

  /// 'YYYY-MM' with visits only; a month with none is left out (drawn as an empty stub).
  final List<({String month, int visits, int totalSen})> months;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final now = DateTime.now();
    final last = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    String key(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final byMonth = {for (final m in months) m.month: m.totalSen};
    final top = byMonth.values.fold(0, (a, b) => a > b ? a : b);
    final locale = Localizations.localeOf(context).toString();
    return SizedBox(
      key: const ValueKey('spend-chart'),
      height: 132,
      child: CustomPaint(
        painter: _SpendPainter(
          nb: nb,
          values: [for (final m in last) byMonth[key(m)] ?? 0],
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
  const _SpendPainter({
    required this.nb,
    required this.values,
    required this.labels,
    required this.current,
    required this.top,
    required this.textScaler,
  });

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
    final bottom = size.height - _labelHeight;
    final plot = bottom - _topPad;
    final max = top <= 0 ? 1 : top;
    final grid = Paint()
      ..color = nb.line
      ..strokeWidth = 1;
    for (final part in const [0.0, 0.5, 1.0]) {
      final y = bottom - plot * part;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _label(
      canvas,
      'RM ${(top / 100).round()}',
      const Offset(0, 0),
      nb.inkSoft,
      FontWeight.w500,
    );
    final slot = size.width / values.length;
    final barWidth = (slot * 0.62).clamp(2.0, 22.0);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
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
