import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/market.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import 'map_sheet.dart';
import 'market_days.dart';
import 'place_category.dart';

/// A market tapped on the map: what is on today, its days, then save or open it, and directions.
class MarketSheet extends StatefulWidget {
  const MarketSheet({
    super.key,
    required this.market,
    required this.places,
    required this.onSaved,
    this.distanceM,
  });

  final Market market;
  final PlacesController places;

  /// From the phone; null = location unknown.
  final int? distanceM;

  /// The caller's new save of this market.
  final ValueChanged<String> onSaved;

  @override
  State<MarketSheet> createState() => _MarketSheetState();
}

class _MarketSheetState extends State<MarketSheet> {
  bool _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final place = await widget.places.saveBranch(widget.market.branchId);
      widget.onSaved(place.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = widget.market;
    final today = marketToday(m.schedule, malaysiaNow());
    final button = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 46)),
    );
    return ListView(
      key: const ValueKey('market-sheet'),
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
      children: [
        Text(
          m.name,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: spaceXs),
        Text(
          [
            placeSubcategoryLabel(l, m.subcategory),
            if (m.label != null && m.label != m.name) m.label!,
            if (widget.distanceM case final d?) distanceText(d),
          ].join(' · '),
          style: text.bodyMedium?.copyWith(color: nb.inkSoft),
        ),
        if (today != null)
          Text(
            marketTodayText(context, today),
            style: text.bodyMedium?.copyWith(
              color: today.openNow ? nb.pandanDeep : nb.ink,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (m.schedule.isNotEmpty)
          Text(
            l.marketNotToday,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        const SizedBox(height: spaceM),
        MarketDaysList(schedule: m.schedule),
        const SizedBox(height: spaceM),
        Row(
          children: [
            Expanded(
              child: m.savedPlaceId != null
                  ? FilledButton(
                      key: const ValueKey('market-open'),
                      style: button,
                      onPressed: () {
                        sheetCloser(context)(null);
                        context.push('/places/${m.savedPlaceId}');
                      },
                      child: Text(l.openPlace),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('market-save'),
                      style: button,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bookmark_add_outlined),
                      label: Text(l.save),
                      onPressed: _saving ? null : _save,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => openLink(
                  context,
                  mapsSearchUrl(m.lat, m.lng),
                  failed: l.openFailed,
                ),
                icon: const Icon(Icons.directions),
                label: Text(l.directions),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
