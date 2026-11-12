import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
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

/// The top places by spend; scrolls with the list, under the collapsing header.
class _TopPlaces extends StatelessWidget {
  const _TopPlaces({required this.stats});

  final ReceiptStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.places.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(spaceM, 4, spaceM, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.spendingTopPlaces,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final p in stats.places.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${l.receiptVisitCount(p.visits)} · ${rm(p.totalSen)}',
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

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
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
