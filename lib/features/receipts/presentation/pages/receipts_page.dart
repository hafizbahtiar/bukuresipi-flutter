import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';
import '../widgets/spend_chart.dart';

/// The user's own spending (last 12 months, from saved receipts) above their receipts, newest first. Private.
/// The Receipts side of the Receipts | Calories switch.
class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key, this.switcher, this.refresh = 0});

  /// The Receipts | Calories switch, under the title.
  final PreferredSizeWidget? switcher;

  /// Bumped each time the page is switched to: it loads again, keeping what it shows until the new data is in.
  final int refresh;

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  late final _repo = context.read<ReceiptsRepository>();
  final _scroll = ScrollController();
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

  Future<void> _refresh() async {
    setState(() {
      _data = _load();
    });
    await _data;
  }

  @override
  void didUpdateWidget(covariant ReceiptsPage old) {
    super.didUpdateWidget(old);
    // FutureBuilder keeps the last data while this loads: no spinner flash on a switch.
    if (old.refresh != widget.refresh) _data = _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.receiptsTitle),
        bottom: widget.switcher,
      ),
      body: NotebookPage(
        child: FutureBuilder(
          future: _data,
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text(errorText(l, s.error!)));
            }
            final data = s.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final (stats, first) = data;
            final receipts = [...first, ..._more];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Part of the list (so a pull anywhere refreshes); scrolls away going down, floats back going up.
                  SliverFloatingHeader(
                    key: const ValueKey('receipts-header'),
                    animationStyle: MediaQuery.disableAnimationsOf(context)
                        ? AnimationStyle.noAnimation
                        : AnimationStyle(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          ),
                    child: ColoredBox(
                      color: Notebook.of(context).paper,
                      child: _Spending(stats: stats),
                    ),
                  ),
                  SliverToBoxAdapter(child: _TopPlaces(stats: stats)),
                  if (receipts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          notebookGutter + 10,
                          24,
                          20,
                          0,
                        ),
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
                        return NotebookRow(
                          key: ValueKey('receipt-${r.id}'),
                          onTap: () => _open(r.id),
                          trailing: Text(
                            r.totalSen == null ? '' : rm(r.totalSen!),
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.place?.name ?? r.shop ?? l.addReceipt,
                                style: text.titleMedium,
                              ),
                              Text(
                                [
                                  if (r.visitedAt != null)
                                    loc.formatMediumDate(r.visitedAt!),
                                  if (r.inReview) l.receiptToCheck,
                                  if (r.reading) l.receiptReading,
                                  if (r.failed)
                                    (r.notRestaurant
                                            ? l.receiptNotRestaurant
                                            : l.receiptFailed)
                                        .split('.')
                                        .first,
                                ].join(' · '),
                                style: text.bodySmall?.copyWith(
                                  color: r.inReview ? nb.kunyit : nb.inkSoft,
                                ),
                              ),
                            ],
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 8),
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
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 4, 20, 8),
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
