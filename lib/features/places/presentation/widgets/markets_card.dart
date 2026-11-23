import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/market.dart';
import '../../domain/nearby_branch.dart';
import 'market_days.dart';

/// Home: the pasar near the phone that are still on today. A tap opens that market on the map.
class MarketsCard extends StatelessWidget {
  const MarketsCard({super.key, required this.items, required this.onTap});

  final List<({Market market, MarketToday today})> items;
  final ValueChanged<Market> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      key: const ValueKey('feed-markets'),
      color: nb.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: nb.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: nb.mist,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.storefront_outlined, color: nb.pandanDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.marketsNearTitle,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final (:market, :today) in items)
            InkWell(
              key: ValueKey('feed-market-${market.branchId}'),
              onTap: () => onTap(market),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              market.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${distanceText(market.distanceM)} · '
                              '${marketTodayText(context, today)}',
                              style: text.bodySmall?.copyWith(
                                color: today.openNow
                                    ? nb.pandanDeep
                                    : nb.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: nb.inkSoft),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
