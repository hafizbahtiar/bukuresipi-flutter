import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/pill_switch.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';
import '../widgets/calorie_chart.dart';
import 'meal_page.dart';

/// Today's calories against the target, the last 7 / 30 days as a chart with the target line, and the day's eaten
/// lines. The Calories side of the Receipts tab: slivers under its pinned switch (ReceiptsTab). Private: the caller's own receipts.
class CaloriesSection extends StatefulWidget {
  const CaloriesSection({super.key});

  @override
  State<CaloriesSection> createState() => CaloriesSectionState();
}

class CaloriesSectionState extends State<CaloriesSection> {
  late final _repo = context.read<ReceiptsRepository>();
  int _range = 30;
  late Future<(DailyCalories, CalorieDays)> _data = _load();

  Future<(DailyCalories, CalorieDays)> _load() =>
      (_repo.calories(), _repo.calorieDays(days: _range)).wait;

  /// The daily target dialog; empty = none.
  Future<void> _setTarget(int? current) async {
    final l = AppLocalizations.of(context);
    final field = TextEditingController(text: current?.toString() ?? '');
    final ok = await showBaseDialog(
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

  /// Camera or photos, then the estimate page; a saved meal reloads the day.
  Future<void> _snapMeal() async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.mealSnap),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.receiptFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    // 1600 px is plenty to tell dishes apart and keeps the upload small.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MealPage(path: picked.path)),
    );
    if (saved == true && mounted) await refresh();
  }

  /// A saved meal: change its dishes, servings or time, or delete it.
  Future<void> _openMeal(DayMeal meal) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => MealPage(meal: meal)));
    if (changed == true && mounted) await refresh();
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
    return FutureBuilder(
      future: _data,
      builder: (context, s) {
        if (s.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(errorText(l, s.error!)),
                  TextButton(onPressed: refresh, child: Text(l.tryAgain)),
                ],
              ),
            ),
          );
        }
        final data = s.data;
        if (data == null) {
          return const SliverToBoxAdapter(child: SkeletonRows(rows: 4));
        }
        final (today, days) = data;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              key: const ValueKey('calories-header'),
              child: _Header(
                today: today,
                days: days,
                range: _range,
                onRange: _setRange,
                onTarget: () => _setTarget(today.target),
                onSnap: _snapMeal,
              ),
            ),
            SliverToBoxAdapter(
              child: _DayItems(
                today: today,
                onOpen: _open,
                onOpenMeal: _openMeal,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _g(double n) => n.round().toString();

class _Header extends StatelessWidget {
  const _Header({
    required this.today,
    required this.days,
    required this.range,
    required this.onRange,
    required this.onTarget,
    required this.onSnap,
  });

  final DailyCalories today;
  final CalorieDays days;
  final int range;
  final ValueChanged<int> onRange;
  final VoidCallback onTarget;
  final VoidCallback onSnap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final target = today.target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 8),
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
          if (today.macros case final m?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.mealMacros(_g(m.carbsG), _g(m.proteinG), _g(m.fatG)),
                style: text.bodyMedium,
              ),
            ),
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
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('snap-meal'),
                onPressed: onSnap,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l.mealSnap),
              ),
              TextButton(
                key: const ValueKey('kcal-target-button'),
                onPressed: onTarget,
                child: Text(
                  target == null ? l.caloriesSetTarget : l.caloriesChangeTarget,
                ),
              ),
            ],
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

/// The day's saved receipts and meals with their eaten lines, newest first; a tap opens the receipt or the meal.
class _DayItems extends StatelessWidget {
  const _DayItems({
    required this.today,
    required this.onOpen,
    required this.onOpenMeal,
  });

  final DailyCalories today;
  final ValueChanged<String> onOpen;
  final ValueChanged<DayMeal> onOpenMeal;

  static String _qty(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : '$n';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    Widget entry({
      required Key key,
      required VoidCallback onTap,
      required String title,
      required DateTime at,
      required int kcal,
      required List<({String name, double eaten, int? kcal})> items,
    }) => ListTile(
      key: key,
      onTap: onTap,
      trailing: Text(
        l.caloriesKcal('$kcal'),
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          Text(
            loc.formatTimeOfDay(TimeOfDay.fromDateTime(at)),
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: 4),
          for (final i in items)
            Text(
              [
                '${_qty(i.eaten)} × ${i.name}',
                if (i.kcal != null) l.caloriesKcal('${i.kcal}'),
              ].join(' · '),
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
        ],
      ),
    );
    final entries = <(DateTime, Widget)>[
      for (final r in today.receipts)
        (
          r.visitedAt,
          entry(
            key: ValueKey('calories-receipt-${r.id}'),
            onTap: () => onOpen(r.id),
            title: r.shop ?? l.addReceipt,
            at: r.visitedAt,
            kcal: r.eatenKcal,
            items: [
              for (final i in r.items)
                (name: i.name, eaten: i.eaten, kcal: i.kcal),
            ],
          ),
        ),
      for (final m in today.meals)
        (
          m.eatenAt,
          entry(
            key: ValueKey('calories-meal-${m.id}'),
            onTap: () => onOpenMeal(m),
            title: l.mealRow,
            at: m.eatenAt,
            kcal: m.eatenKcal,
            items: [
              for (final i in m.items)
                (name: i.name, eaten: i.eaten, kcal: i.kcal),
            ],
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 0),
          child: Text(
            l.caloriesItemsTitle,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 0),
            child: Text(
              l.caloriesNoItems,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          )
        else
          for (final e in entries) e.$2,
      ],
    );
  }
}
