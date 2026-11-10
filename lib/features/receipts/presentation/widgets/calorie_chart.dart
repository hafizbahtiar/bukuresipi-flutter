import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/receipt.dart';

/// One bar per day, today deepest, days over the target in the margin red, and the target as a dashed line. All with
/// one painter (no chart package); labels thin out over 30 days.
class CalorieChart extends StatelessWidget {
  const CalorieChart({super.key, required this.days, this.target});

  /// Oldest first; the last one is today.
  final List<CalorieDay> days;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final locale = Localizations.localeOf(context).toString();
    final weekdays = DateFormat.E(locale);
    return SizedBox(
      key: const ValueKey('calorie-chart'),
      height: 132,
      child: CustomPaint(
        painter: _CaloriePainter(
          nb: nb,
          values: [for (final d in days) d.eatenKcal],
          labels: [
            for (var i = 0; i < days.length; i++)
              days.length <= 7
                  ? weekdays.format(days[i].date)
                  : (i % 5 == 0 || i == days.length - 1
                        ? '${days[i].date.day}'
                        : ''),
          ],
          target: target,
          targetLabel: target == null ? null : l.caloriesKcal('$target'),
          today: days.length - 1,
          textScaler: MediaQuery.textScalerOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CaloriePainter extends CustomPainter {
  const _CaloriePainter({
    required this.nb,
    required this.values,
    required this.labels,
    required this.target,
    required this.targetLabel,
    required this.today,
    required this.textScaler,
  });

  final Notebook nb;
  final List<int> values;
  final List<String> labels;
  final int? target;
  final String? targetLabel;
  final int today;
  final TextScaler textScaler;

  static const _labelHeight = 18.0;
  static const _topPad = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final bottom = size.height - _labelHeight;
    final plot = bottom - _topPad;
    final top =
        math
            .max(1, math.max(values.fold(0, math.max), target ?? 0))
            .toDouble() *
        1.12;
    final grid = Paint()
      ..color = nb.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), grid);
    canvas.drawLine(Offset(0, _topPad), Offset(size.width, _topPad), grid);

    final slot = size.width / values.length;
    final barWidth = (slot * 0.62).clamp(1.5, 22.0);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final height = value <= 0 ? 2.0 : 2 + (plot - 2) * value / top;
      final left = slot * i + (slot - barWidth) / 2;
      final color = value <= 0
          ? nb.line
          : (target != null && value > target!
                ? nb.margin
                : (i == today
                      ? nb.pandanDeep
                      : nb.pandan.withValues(alpha: 0.75)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, bottom - height, barWidth, height),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
      if (labels[i].isEmpty) continue;
      final label = _text(
        labels[i],
        i == today ? nb.ink : nb.inkSoft,
        i == today ? FontWeight.w700 : FontWeight.w400,
      );
      label.paint(
        canvas,
        Offset(slot * i + (slot - label.width) / 2, bottom + 4),
      );
    }

    if (target != null && targetLabel != null) {
      final y = bottom - plot * (target! / top);
      final dash = Paint()
        ..color = nb.kunyit
        ..strokeWidth = 1.6;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      }
      final label = _text(targetLabel!, nb.inkSoft, FontWeight.w600);
      label.paint(
        canvas,
        Offset(
          math.max(0, size.width - label.width),
          math.max(0, y - label.height - 1),
        ),
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

  @override
  bool shouldRepaint(_CaloriePainter old) =>
      old.target != target ||
      old.today != today ||
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
