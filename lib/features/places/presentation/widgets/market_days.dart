import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/market.dart';

/// "Saturday" / "Sabtu" for an ISO day (1 January 2024 is a Monday).
String marketDayName(BuildContext context, int day) =>
    intl.DateFormat.EEEE(Localizations.localeOf(context).languageCode)
        .format(DateTime(2024, 1, day));

/// "HH:MM" as the phone shows times.
String marketClock(BuildContext context, String hhmm) {
  final [h, m] = hhmm.split(':').map(int.parse).toList();
  return formatTime(context, DateTime(2024, 1, 1, h, m));
}

String marketHours(BuildContext context, MarketDay d) =>
    '${marketClock(context, d.opens)} – ${marketClock(context, d.closes)}';

/// "Open now · until 10:00 PM", or today's hours when it opens later.
String marketTodayText(BuildContext context, MarketToday t) => t.openNow
    ? AppLocalizations.of(context)
          .marketOpenUntil(marketClock(context, t.slot.closes))
    : marketHours(context, t.slot);

/// One line for any place: "Open now · until 3:00 PM", "Break until 5:00 PM", "Opens 11:00 AM"; null = nothing
/// more today or hours not known (never "closed").
String? hoursTodayText(
  BuildContext context,
  List<MarketDay> schedule, [
  DateTime? now,
]) {
  final t = marketToday(schedule, now ?? malaysiaNow());
  if (t == null) return null;
  final l = AppLocalizations.of(context);
  if (t.openNow) return marketTodayText(context, t);
  final at = marketClock(context, t.slot.opens);
  return t.breakNow ? l.hoursBreakUntil(at) : l.hoursOpensAt(at);
}

/// A market's weekly days and hours, today in bold. None = "not known yet", never a guess.
class MarketDaysList extends StatelessWidget {
  const MarketDaysList({
    super.key,
    required this.schedule,
    this.heading = true,
    this.now,
    this.market = true,
  });

  final List<MarketDay> schedule;

  /// false = any other place's opening hours (its own title and "not known" words).
  final bool market;

  /// Its own small title; false under a page's section header.
  final bool heading;

  /// Malaysia time; null = the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final today = (now ?? malaysiaNow()).weekday;
    final days = [...schedule]
      ..sort((a, b) {
        final byDay = a.day.compareTo(b.day);
        return byDay != 0 ? byDay : a.opensAt.compareTo(b.opensAt);
      });
    final todayLine = market ? null : hoursTodayText(context, schedule, now);
    return Column(
      key: const ValueKey('market-days'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading)
          Padding(
            padding: const EdgeInsets.only(bottom: spaceXs),
            child: Text(
              market ? l.marketDaysTitle : l.hoursTitle,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        // A market's sheet shows its own today line above this list.
        if (todayLine case final t?)
          Padding(
            padding: const EdgeInsets.only(bottom: spaceXs),
            child: Text(t, style: text.bodyMedium),
          ),
        if (days.isEmpty)
          Text(
            market ? l.marketDaysUnknown : l.hoursUnknown,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: DefaultTextStyle.merge(
              style: text.bodyMedium?.copyWith(
                fontWeight: d.day == today ? FontWeight.w700 : null,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(marketDayName(context, d.day))),
                  const SizedBox(width: spaceS),
                  Text(marketHours(context, d)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
