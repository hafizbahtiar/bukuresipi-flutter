import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/places_controller.dart';
import '../../../places/presentation/widgets/halal_status.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';
import '../widgets/spend_chart.dart';

/// The user's own spending (last 12 months, from saved receipts) above their receipts, newest first. Private.
/// The Receipts side of the Receipts tab: slivers under its pinned switch (ReceiptsTab).
class ReceiptsSection extends StatefulWidget {
  const ReceiptsSection({super.key});

  @override
  State<ReceiptsSection> createState() => ReceiptsSectionState();
}

class ReceiptsSectionState extends State<ReceiptsSection> {
  late final _repo = context.read<ReceiptsRepository>();
  late Future<(ReceiptStats, List<Receipt>)> _data = _load();

  /// Pages after the first ("Load more"); [_next] = the cursor of the page after them, null on the last.
  final _more = <Receipt>[];
  String? _next;
  bool _loadingMore = false;

  Future<(ReceiptStats, List<Receipt>)> _load() async {
    final (stats, list) = await (_repo.stats(), _repo.list()).wait;
    _more.clear();
    _next = list.next;
    return (stats, list.items);
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.list(cursor: _next);
      if (!mounted) return;
      setState(() {
        _more.addAll(page.items);
        _next = page.next;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText(AppLocalizations.of(context), e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(String id) async {
    await context.push('/receipts/$id');
    if (mounted) {
      setState(() {
        _data = _load();
      });
    }
  }

  /// Loads again; what is shown stays until the new data is in (FutureBuilder keeps the last data).
  Future<void> refresh() async {
    setState(() {
      _data = _load();
    });
    await _data;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    return FutureBuilder(
      future: _data,
      builder: (context, s) {
        if (s.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorText(l, s.error!)),
            ),
          );
        }
        final data = s.data;
        if (data == null) {
          return const SliverToBoxAdapter(child: SkeletonRows());
        }
        final (stats, first) = data;
        final receipts = [...first, ..._more];
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              key: const ValueKey('receipts-header'),
              child: _Spending(stats: stats),
            ),
            SliverToBoxAdapter(child: _TopPlaces(stats: stats)),
            if (receipts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(spaceM, 24, spaceM, 0),
                  child: Text(
                    l.receiptsEmpty,
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: receipts.length,
                itemBuilder: (context, index) {
                  final r = receipts[index];
                  return BaseTile(
                    key: ValueKey('receipt-${r.id}'),
                    onTap: () => _open(r.id),
                    leading: BaseTile.icon(
                      context,
                      r.failed
                          ? Icons.error_outline
                          : Icons.receipt_long_outlined,
                      color: r.failed ? nb.margin : null,
                    ),
                    title: r.place?.name ?? r.shop ?? l.addReceipt,
                    subtitle: r.visitedAt == null
                        ? null
                        : loc.formatMediumDate(r.visitedAt!),
                    tags: [
                      if (r.inReview)
                        TileTag(l.receiptToCheck, tone: TagTone.warn),
                      if (r.reading) TileTag(l.receiptReading),
                      if (r.failed)
                        TileTag(
                          (r.notRestaurant
                                  ? l.receiptNotRestaurant
                                  : l.receiptFailed)
                              .split('.')
                              .first,
                          tone: TagTone.danger,
                        ),
                    ],
                    trailing: Text(
                      r.totalSen == null ? '' : rm(r.totalSen!),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                },
              ),
            if (_next != null)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton(
                    key: const ValueKey('receipts-more'),
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(l.loadMore),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Spending extends StatelessWidget {
  const _Spending({required this.stats});

  final ReceiptStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.spendingTitle,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Figure(label: l.spendingSpent, value: rm(stats.totalSen)),
              _Figure(label: l.spendingVisits, value: '${stats.visits}'),
            ],
          ),
          const SizedBox(height: 12),
          SpendChart(months: stats.months),
        ],
      ),
    );
  }
}

/// The top places by spend as a sideways strip of cards (most spent first), between the chart and the receipts.
class _TopPlaces extends StatelessWidget {
  const _TopPlaces({required this.stats});

  final ReceiptStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.places.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spaceM),
            child: Text(
              l.spendingTopPlaces,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          // Ten cards at most: a plain Row is fine, and IntrinsicHeight gives them one height at any text size.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: spaceM),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, p) in stats.places.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: () => showBaseSheet<void>(
                          context,
                          builder: (_) => PlaceVisitsSheet(place: p),
                        ),
                        child: _PlaceCard(
                          key: ValueKey('top-place-${p.placeId}'),
                          rank: i + 1,
                          place: p,
                          totalSen: stats.totalSen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One top place: its cover and rank, the name, what was spent there, visits and the last one, its share of the total.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    super.key,
    required this.rank,
    required this.place,
    required this.totalSen,
  });

  static const _width = 168.0;

  final int rank;
  final SpendPlace place;

  /// Everything spent in the window: the share bar's whole.
  final int totalSen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final share = totalSen <= 0
        ? 0.0
        : (place.totalSen / totalSen).clamp(0.0, 1.0);
    final icon = Icon(Icons.storefront, size: 28, color: nb.pandanDeep);
    return Container(
      width: _width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: nb.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            width: _width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: nb.mist,
                  child: switch (place.cover) {
                    final cover? => ShareFill(
                      id: cover,
                      placeId: place.placeId,
                      fallback: Center(child: icon),
                      cacheWidth: 500,
                    ),
                    null => Center(child: icon),
                  },
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: nb.paper,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$rank',
                      style: text.labelSmall?.copyWith(
                        color: nb.pandanDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 6),
                  Text(
                    rm(place.totalSen),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    [
                      l.receiptVisitCount(place.visits),
                      if (place.lastVisitAt case final at?)
                        l.spendingLastVisit(loc.formatShortMonthDay(at)),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 5,
                      color: nb.pandan,
                      backgroundColor: nb.mist,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.spendingShare((share * 100).round()),
                    style: text.labelSmall?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.small = false});

  final String label;
  final String value;

  /// In a sheet: three side by side, on a 320 dp phone too.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: Notebook.of(context).inkSoft),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (small ? text.titleMedium : text.headlineSmall)?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A place the user has been to (Spending > a top place): what they spent there in all, how often, the average, the
/// first and last visit, then every visit by day (a day's total when it had more than one); a visit opens its
/// receipt. The halal badge is the user's Book entry's (saving a receipt puts the place there).
class PlaceVisitsSheet extends StatefulWidget {
  const PlaceVisitsSheet({super.key, required this.place});

  final SpendPlace place;

  /// shortcut: one page of visits (the newest 50), enough for one place; page it if someone passes 50 visits.
  static const _limit = 50;

  @override
  State<PlaceVisitsSheet> createState() => _PlaceVisitsSheetState();
}

class _PlaceVisitsSheetState extends State<PlaceVisitsSheet> {
  late final Future<List<Receipt>> _visits = context
      .read<ReceiptsRepository>()
      .list(place: widget.place.placeId, limit: PlaceVisitsSheet._limit)
      // The API pages by save order; a visit list reads by when it happened.
      .then(
        (p) => [...p.items]
          ..sort(
            (a, b) => (b.visitedAt ?? DateTime(0)).compareTo(
              a.visitedAt ?? DateTime(0),
            ),
          ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final book = context
        .watch<PlacesController?>()
        ?.places
        .where((p) => p.restaurant.id == widget.place.placeId)
        .firstOrNull;
    final r = book?.restaurant;
    final now = DateTime.now();
    final halal = r == null || !r.isFood
        ? null
        : book!.branches.any(
            (b) => !b.closed && b.halalCert?.expiredAt(now) == false,
          )
        ? HalalKind.jakim
        : HalalKind.ofClaim(r.halalQuote == null ? null : r.halalClaim);
    return FutureBuilder(
      future: _visits,
      builder: (context, snap) {
        final visits = snap.data;
        final total = visits?.fold(0, (s, v) => s + (v.totalSen ?? 0)) ?? 0;
        final days = <DateTime, List<Receipt>>{};
        for (final v in visits ?? const <Receipt>[]) {
          final at = v.visitedAt;
          if (at == null) continue;
          (days[DateTime(at.year, at.month, at.day)] ??= []).add(v);
        }
        return ListView(
          key: const ValueKey('place-visits'),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (halal != null && halal != HalalKind.none)
                    HalalBadge(halal),
                ],
              ),
            ),
            if (snap.hasError)
              Padding(
                padding: const EdgeInsets.all(spaceM),
                child: Text(errorText(l, snap.error!)),
              )
            else if (visits == null)
              const Padding(
                padding: EdgeInsets.all(spaceL),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
                child: Row(
                  children: [
                    for (final (label, value) in [
                      (l.spendingSpent, rm(total)),
                      (l.spendingVisits, '${visits.length}'),
                      (
                        l.spendingAverage,
                        visits.isEmpty
                            ? '-'
                            : rm((total / visits.length).round()),
                      ),
                    ])
                      Expanded(
                        child: _Figure(label: label, value: value, small: true),
                      ),
                  ],
                ),
              ),
              if (days.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(spaceM, 6, spaceM, 0),
                  child: Text(
                    l.spendingFirstLast(
                      loc.formatMediumDate(days.keys.last),
                      loc.formatMediumDate(days.keys.first),
                    ),
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ),
              const SizedBox(height: spaceS),
              for (final MapEntry(key: day, value: list) in days.entries) ...[
                SectionHeader(
                  list.length > 1
                      ? '${loc.formatFullDate(day)} · ${rm(list.fold(0, (s, v) => s + (v.totalSen ?? 0)))}'
                      : loc.formatFullDate(day),
                ),
                for (final v in list)
                  ListTile(
                    key: ValueKey('visit-${v.id}'),
                    dense: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/receipts/${v.id}');
                    },
                    leading: Icon(
                      Icons.receipt_long_outlined,
                      color: nb.inkSoft,
                    ),
                    title: Text(
                      loc.formatTimeOfDay(TimeOfDay.fromDateTime(v.visitedAt!)),
                      style: text.bodyLarge,
                    ),
                    trailing: Text(
                      v.totalSen == null ? '' : rm(v.totalSen!),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
              if (book != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    spaceM,
                    spaceS,
                    spaceM,
                    spaceM,
                  ),
                  child: OutlinedButton.icon(
                    key: const ValueKey('place-visits-open'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/places/${book.id}');
                    },
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(l.placeVisitsOpen),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
