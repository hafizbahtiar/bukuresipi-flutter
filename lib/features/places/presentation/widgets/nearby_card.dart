import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/rating.dart';
import 'market_days.dart';

/// One nearby restaurant: cover, name, distance, branch or address, stars, cuisine, a quoted halal claim. The map sheet's list.
class NearbyCard extends StatelessWidget {
  /// Grows with the phone's text size: the card holds up to four lines of text.
  static double heightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(96);

  const NearbyCard({
    this.now,
    super.key,
    required this.place,
    this.selected = false,
    required this.onTap,
  });

  /// Malaysia time for today's hours; null = the clock.
  final DateTime? now;

  final NearbyBranch place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final label = place.label?.trim();
    final address = place.address?.trim();
    // One line under the name: the branch when it says more than the name, else the address.
    final where = label != null && label.isNotEmpty && label != place.name
        ? label
        : (address != null && address.isNotEmpty ? address : null);
    // Today's hours first on the same line: the card keeps its height.
    final today = hoursTodayText(context, place.schedule, now);
    final under = [?today, ?where].join(' · ');
    final cuisine = place.cuisine?.trim();
    // A quoted claim from the post, never "certified" (as the Home feed).
    final saysHalal =
        place.halalClaim == 'says_halal' &&
        (place.halalQuote?.trim().isNotEmpty ?? false);
    final icon = Icon(Icons.storefront, size: 22, color: nb.pandanDeep);
    Widget tag(String t, {IconData? icon, Color? color}) => _InfoTag(
      text: t,
      icon: icon,
      color: color ?? nb.inkSoft,
      background: nb.mist,
      border: nb.line,
    );
    return Material(
      color: nb.paper,
      elevation: selected ? 4 : 2,
      shadowColor: nb.ink.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? nb.pandan : nb.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed width: the text needs the room; the height follows the card.
            SizedBox(
              width: 72,
              child: ColoredBox(
                color: nb.mist,
                child: switch (place.cover) {
                  final cover? => ShareFill(
                    key: ValueKey('nearby-cover-$cover'),
                    id: cover,
                    placeId: place.placeId,
                    fallback: Center(child: icon),
                  ),
                  null => Center(child: icon),
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _DistancePill(
                          label: distanceText(place.distanceM),
                          background: nb.mist,
                          foreground: nb.pandanDeep,
                        ),
                      ],
                    ),
                    if (under.isNotEmpty)
                      Text(
                        under,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    Row(
                      children: [
                        if (place.rating
                            case RatingSummary(:final average?, :final count)
                            when count > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: nb.pandanDeep,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${average.toStringAsFixed(1)} ($count)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // A long cuisine shrinks to an ellipsis instead of pushing the row off the card.
                        Expanded(
                          child: Row(
                            children: [
                              if (cuisine != null && cuisine.isNotEmpty) ...[
                                Flexible(child: tag(cuisine)),
                                const SizedBox(width: 6),
                              ],
                              // This outlet on JAKIM (not expired) first, as Home; else the post's quoted claim.
                              if (place.jakimHalal)
                                Flexible(
                                  child: tag(
                                    l.feedJakimHalal,
                                    icon: Icons.verified_outlined,
                                    color: nb.pandanDeep,
                                  ),
                                )
                              else if (saysHalal)
                                Flexible(
                                  child: tag(
                                    l.feedSaysHalal,
                                    icon: Icons.format_quote_rounded,
                                    color: nb.pandanDeep,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (place.saved)
                          Icon(
                            Icons.bookmark,
                            size: 18,
                            color: nb.pandanDeep,
                            semanticLabel: l.nearbySavedTag,
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: nb.inkSoft,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
    ),
  );
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({
    required this.text,
    required this.color,
    required this.background,
    required this.border,
    this.icon,
  });

  final String text;
  final Color color;
  final Color background;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon case final icon?) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
