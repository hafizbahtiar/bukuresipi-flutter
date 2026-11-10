import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/collapsing_header.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/pill_switch.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';
import '../widgets/calorie_chart.dart';

/// Today's calories against the target, the last 7 / 30 days as a chart with the target line, and the day's eaten
/// lines. The Calories side of the Receipts | Calories switch. Private: the caller's own receipts.
class CaloriesPage extends StatefulWidget {
  const CaloriesPage({super.key, this.switcher});

  /// The Receipts | Calories switch, under the title.
  final PreferredSizeWidget? switcher;

  @override
  State<CaloriesPage> createState() => _CaloriesPageState();
}

class _CaloriesPageState extends State<CaloriesPage> {
  late final _repo = context.read<ReceiptsRepository>();
  final _scroll = ScrollController();
  int _range = 30;
  late Future<(DailyCalories, CalorieDays)> _data = _load();

  Future<(DailyCalories, CalorieDays)> _load() =>
      (_repo.calories(), _repo.calorieDays(days: _range)).wait;

  /// The daily target dialog; empty = none.
  Future<void> _setTarget(int? current) async {
    final l = AppLocalizations.of(context);
    final field = TextEditingController(text: current?.toString() ?? '');
    final ok = await showNotebookDialog(
      context,
      title: l.caloriesTarget,
      message: l.caloriesTargetRange,
      confirmLabel: l.save,
      content: TextField(
        key: const ValueKey('kcal-target'),
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(suffixText: 'kcal'),
      ),
    );
    // Not disposed here: the dialog's closing animation still shows the field.
    final text = field.text.trim();
    if (!ok || !mounted) return;
    final kcal = int.tryParse(text);
    if (text.isNotEmpty && (kcal == null || kcal < 500 || kcal > 10000)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.caloriesTargetRange)));
      return;
    }
    try {
      await context.read<AuthController>().setKcalTarget(kcal);
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(l, e))));
      }
    }
  }

  void _setRange(int range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _data = _load();
    });
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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.navCalories),
        bottom: widget.switcher,
      ),
      body: NotebookPage(
        child: FutureBuilder(
          future: _data,
          builder: (context, s) {
            if (s.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorText(l, s.error!)),
                    TextButton(
                      onPressed: () => setState(() {
                        _data = _load();
                      }),
                      child: Text(l.tryAgain),
                    ),
                  ],
                ),
              );
            }
            final data = s.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final (today, days) = data;
            return Column(
              children: [
                CollapsingHeader(
                  key: const ValueKey('calories-header'),
                  controller: _scroll,
                  child: _Header(
                    today: today,
                    days: days,
                    range: _range,
                    onRange: _setRange,
                    onTarget: () => _setTarget(today.target),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _data = _load();
                      });
                      await _data;
                    },
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _DayItems(today: today, onOpen: _open),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.today,
    required this.days,
    required this.range,
    required this.onRange,
    required this.onTarget,
  });

  final DailyCalories today;
  final CalorieDays days;
  final int range;
  final ValueChanged<int> onRange;
  final VoidCallback onTarget;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final target = today.target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.caloriesToday,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            target == null
                ? l.caloriesKcal('${today.eatenKcal}')
                : l.caloriesTodayOf('${today.eatenKcal}', '$target'),
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (target != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (today.eatenKcal / target).clamp(0, 1).toDouble(),
                minHeight: 6,
                color: today.eatenKcal > target ? nb.margin : nb.pandan,
                backgroundColor: nb.mist,
              ),
            ),
          ],
          if (today.hasEstimate || today.unknownEaten > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (today.hasEstimate) l.caloriesAiEstimate,
                  if (today.unknownEaten > 0) l.caloriesUnknown,
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ),
          TextButton(
            key: const ValueKey('kcal-target-button'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onTarget,
            child: Text(
              target == null ? l.caloriesSetTarget : l.caloriesChangeTarget,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: PillSwitch<int>(
              value: range,
              expand: false,
              onChanged: onRange,
              options: [
                (7, Text(l.caloriesDays7), null),
                (30, Text(l.caloriesDays30), null),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CalorieChart(days: days.days, target: target),
          const SizedBox(height: 4),
          Text(
            l.caloriesDisclaimer,
            style: text.bodySmall?.copyWith(color: nb.inkSoft, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The day's saved receipts with their eaten lines; a tap opens the receipt.
class _DayItems extends StatelessWidget {
  const _DayItems({required this.today, required this.onOpen});

  final DailyCalories today;
  final ValueChanged<String> onOpen;

  static String _qty(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : '$n';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 0),
          child: Text(
            l.caloriesItemsTitle,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (today.receipts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 0),
            child: Text(
              l.caloriesNoItems,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          )
        else
          for (final r in today.receipts)
            NotebookRow(
              key: ValueKey('calories-receipt-${r.id}'),
              onTap: () => onOpen(r.id),
              trailing: Text(
                l.caloriesKcal('${r.eatenKcal}'),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.shop ?? l.addReceipt, style: text.titleMedium),
                  Text(
                    loc.formatTimeOfDay(TimeOfDay.fromDateTime(r.visitedAt)),
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  for (final i in r.items)
                    Text(
                      [
                        '${_qty(i.eaten)} × ${i.name}',
                        if (i.kcal != null) l.caloriesKcal('${i.kcal}'),
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
