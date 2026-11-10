import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';

/// The user's own spending (last 12 months, from saved receipts) above their receipts, newest first. Private.
class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.receiptsTitle)),
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
              onRefresh: () async {
                setState(() {
                  _data = _load();
                });
                await _data;
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Spending(stats: stats),
                  if (receipts.isEmpty)
                    Padding(
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
                  for (final r in receipts)
                    NotebookRow(
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
                              if (r.failed) l.receiptFailed.split('.').first,
                            ].join(' · '),
                            style: text.bodySmall?.copyWith(
                              color: r.inReview ? nb.kunyit : nb.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_next != null)
                    Center(
                      child: TextButton(
                        key: const ValueKey('receipts-more'),
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(l.loadMore),
                      ),
                    ),
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
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    // The last 12 months, oldest first; a month with no visit is an empty bar.
    final now = DateTime.now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    String key(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final byMonth = {for (final m in stats.months) m.month: m.totalSen};
    final top = byMonth.values.fold(0, (a, b) => a > b ? a : b);
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
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${MaterialLocalizations.of(context).formatMonthYear(m)}: ${rm(byMonth[key(m)] ?? 0)}',
                      child: Container(
                        key: ValueKey('bar-${key(m)}'),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: top == 0
                            ? 2
                            : 2 + 70 * (byMonth[key(m)] ?? 0) / top,
                        decoration: BoxDecoration(
                          color: (byMonth[key(m)] ?? 0) > 0
                              ? nb.pandan
                              : nb.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (stats.places.isNotEmpty) ...[
            const SizedBox(height: 16),
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
