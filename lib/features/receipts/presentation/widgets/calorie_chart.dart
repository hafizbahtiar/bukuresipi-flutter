import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/receipt.dart';

/// One bar per day, today deepest, days over the target in the margin red, and the target as a dashed line. All with
/// one painter (no chart package); labels thin out over 30 days.
/// A change morphs: bars are matched by date, so 30 -> 7 days widens the last week into place while the older days
/// slide off to the left (and back for 7 -> 30); new values and a new scale grow from the old ones.
class CalorieChart extends StatefulWidget {
  const CalorieChart({super.key, required this.days, this.target});

  /// Oldest first; the last one is today.
  final List<CalorieDay> days;
  final int? target;

  @override
  State<CalorieChart> createState() => _CalorieChartState();
}

class _CalorieChartState extends State<CalorieChart>
    with SingleTickerProviderStateMixin {
  late final _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  late List<CalorieDay> _from = widget.days;
  late int? _fromTarget = widget.target;

  @override
  void didUpdateWidget(CalorieChart old) {
    super.didUpdateWidget(old);
    if (_sameDays(old.days, widget.days) && old.target == widget.target) return;
    _from = old.days;
    _fromTarget = old.target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _morph.value = 1;
    } else {
      _morph.forward(from: 0);
    }
  }

  static bool _sameDays(List<CalorieDay> a, List<CalorieDay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].date != b[i].date || a[i].eatenKcal != b[i].eatenKcal) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final weekdays = DateFormat.E(Localizations.localeOf(context).toString());
    List<String> labels(List<CalorieDay> days) => [
      for (var i = 0; i < days.length; i++)
        days.length <= 7
            ? weekdays.format(days[i].date)
            : (i % 5 == 0 || i == days.length - 1 ? '${days[i].date.day}' : ''),
    ];
    final target = widget.target;
    return SizedBox(
      key: const ValueKey('calorie-chart'),
      height: 132,
      child: CustomPaint(
        painter: _CaloriePainter(
          t: CurvedAnimation(parent: _morph, curve: Curves.easeInOutCubic),
          nb: Notebook.of(context),
          from: _from,
          to: widget.days,
          fromLabels: labels(_from),
          toLabels: labels(widget.days),
          fromTarget: _fromTarget,
          target: target,
          targetLabel: target == null ? null : l.caloriesKcal('$target'),
          textScaler: MediaQuery.textScalerOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CaloriePainter extends CustomPainter {
  _CaloriePainter({
    required this.t,
    required this.nb,
    required this.from,
    required this.to,
    required this.fromLabels,
    required this.toLabels,
    required this.fromTarget,
    required this.target,
    required this.targetLabel,
    required this.textScaler,
  }) : super(repaint: t);

  final Animation<double> t;
  final Notebook nb;
  final List<CalorieDay> from, to;
  final List<String> fromLabels, toLabels;
  final int? fromTarget, target;
  final String? targetLabel;
  final TextScaler textScaler;

  static const _labelHeight = 18.0;
  static const _topPad = 18.0;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Days from [first] to [d] (Malaysia has no DST, but round anyway).
  static int _offset(DateTime first, DateTime d) =>
      (d.difference(first).inHours / 24).round();

  static double _scale(List<CalorieDay> days, int? target) =>
      math
          .max(
            1,
            math.max(
              days.fold(0, (m, d) => math.max(m, d.eatenKcal)),
              target ?? 0,
            ),
          )
          .toDouble() *
      1.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (to.isEmpty) return;
    final k = t.value;
    final old = from.isEmpty ? to : from;
    final bottom = size.height - _labelHeight;
    final plot = bottom - _topPad;
    final top = _lerp(_scale(old, fromTarget), _scale(to, target), k);
    final grid = Paint()
      ..color = nb.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), grid);
    canvas.drawLine(Offset(0, _topPad), Offset(size.width, _topPad), grid);

    // Every date in either layout: where it sits (slot centre) and how tall, in the old and in the new layout.
    // A date one layout lacks sits where that layout's spacing would put it (off the left edge) at height 0.
    final oldSlot = size.width / old.length, newSlot = size.width / to.length;
    final slot = _lerp(oldSlot, newSlot, k);
    final barWidth = (slot * 0.62).clamp(1.5, 22.0);
    final oldKcal = {for (final d in old) d.date: d.eatenKcal};
    final newKcal = {for (final d in to) d.date: d.eatenKcal};
    final today = to.last.date;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    for (final date in {...oldKcal.keys, ...newKcal.keys}) {
      final x = _lerp(
        oldSlot * (_offset(old.first.date, date) + 0.5),
        newSlot * (_offset(to.first.date, date) + 0.5),
        k,
      );
      final value = _lerp(
        (oldKcal[date] ?? 0).toDouble(),
        (newKcal[date] ?? 0).toDouble(),
        k,
      );
      final height = value <= 0 ? 2.0 : 2 + (plot - 2) * value / top;
      final color = value <= 0
          ? nb.line
          : (target != null && value > target!
                ? nb.margin
                : (date == today
                      ? nb.pandanDeep
                      : nb.pandan.withValues(alpha: 0.75)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, bottom - height, barWidth, height),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }
    // Labels cross-fade: the old ones out at their moving dates, the new ones in.
    void labelsOf(List<CalorieDay> days, List<String> labels, double alpha) {
      if (alpha <= 0) return;
      for (var i = 0; i < days.length; i++) {
        if (labels[i].isEmpty) continue;
        final date = days[i].date;
        final x = _lerp(
          oldSlot * (_offset(old.first.date, date) + 0.5),
          newSlot * (_offset(to.first.date, date) + 0.5),
          k,
        );
        final isToday = date == today;
        final label = _text(
          labels[i],
          (isToday ? nb.ink : nb.inkSoft).withValues(alpha: alpha),
          isToday ? FontWeight.w700 : FontWeight.w400,
        );
        label.paint(canvas, Offset(x - label.width / 2, bottom + 4));
      }
    }

    if (from.isNotEmpty && k < 1) labelsOf(from, fromLabels, 1 - k);
    labelsOf(to, toLabels, k);
    canvas.restore();

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
      old.from != from ||
      old.to != to ||
      old.target != target ||
      old.nb != nb ||
      old.textScaler != textScaler ||
      old.targetLabel != targetLabel;
}
