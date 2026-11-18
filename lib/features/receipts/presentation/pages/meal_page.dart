import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart' show showBaseDialog;
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/notebook_dialog.dart' show DialogTone;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';

/// A meal photo's estimate: the photo from the phone (never uploaded for keeps) above the dishes the server found,
/// each with servings the user can change, rename or remove. Save = the meal counts in today's calories; pops true.
/// With [meal] instead of [path]: a saved meal to edit (no photo, no estimate) or delete.
class MealPage extends StatefulWidget {
  const MealPage({super.key, this.path, this.meal})
    : assert((path == null) != (meal == null));

  /// The local JPEG of a new meal.
  final String? path;
  final DayMeal? meal;

  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  late final _repo = context.read<ReceiptsRepository>();
  List<MealItem>? _items;
  // One per row, kept across edits: removing a row must not hand its text field to the next one.
  final _keys = <Key>[];
  Object? _error;
  bool _saving = false;
  late DateTime _at = widget.meal?.eatenAt ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.meal case final m?) {
      _items = [...m.items];
      _keys.addAll(m.items.map((_) => UniqueKey()));
    } else {
      _estimate();
    }
  }

  /// Time of day only: a meal snapped later in the day ("lunch") keeps its date.
  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t != null && mounted) {
      setState(
        () => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute),
      );
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showBaseDialog(
      context,
      message: l.mealDelete,
      tone: DialogTone.danger,
      confirmLabel: l.delete,
    );
    if (!ok) return;
    try {
      await _repo.removeMeal(widget.meal!.id);
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _estimate() async {
    setState(() => _error = null);
    try {
      final items = await _repo.estimateMeal(widget.path!);
      if (!mounted) return;
      setState(() {
        _items = [...items];
        _keys.addAll(items.map((_) => UniqueKey()));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _set(int i, MealItem item) => setState(() => _items![i] = item);

  /// A renamed dish loses the estimate's numbers: the server matches the new name on save.
  void _rename(int i, String name) {
    final it = _items![i];
    if (name.trim() == it.name) return;
    _set(i, (
      name: name.trim(),
      eaten: it.eaten,
      kcal: null,
      kcalSource: null,
      carbsG: null,
      proteinG: null,
      fatG: null,
    ));
  }

  void _servings(int i, double delta) {
    final it = _items![i];
    final n = (it.eaten + delta).clamp(0.5, 20).toDouble();
    _set(i, (
      name: it.name,
      eaten: n,
      kcal: it.kcal,
      kcalSource: it.kcalSource,
      carbsG: it.carbsG,
      proteinG: it.proteinG,
      fatG: it.fatG,
    ));
  }

  void _add() => setState(() {
    _keys.add(UniqueKey());
    _items!.add((
      name: '',
      eaten: 1,
      kcal: null,
      kcalSource: null,
      carbsG: null,
      proteinG: null,
      fatG: null,
    ));
  });

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final items = _items!.where((i) => i.name.isNotEmpty).toList();
      if (widget.meal case final m?) {
        await _repo.replaceMeal(m.id, _at, items);
      } else {
        await _repo.saveMeal(_at, items);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.mealSaved)));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 1, 1.5, 0.25: up to two decimals, no trailing zeros.
  static String _num(double n) =>
      n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final items = _items;
    final named = items?.where((i) => i.name.isNotEmpty).toList() ?? const [];
    final total = named.fold<double>(0, (n, i) => n + i.eaten * (i.kcal ?? 0));
    final allMacros =
        named.isNotEmpty &&
        named.every(
          (i) => i.carbsG != null && i.proteinG != null && i.fatG != null,
        );
    double sum(double? Function(MealItem) f) =>
        named.fold(0, (n, i) => n + i.eaten * f(i)!);
    return Scaffold(
      appBar: AppBar(
        title: NotebookTitle(l.mealTitle),
        actions: [
          if (widget.meal != null)
            IconButton(
              key: const ValueKey('meal-delete'),
              tooltip: l.delete,
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: items == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(spaceM),
                child: FilledButton(
                  key: const ValueKey('meal-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _saving || named.isEmpty ? null : _save,
                  child: Text(l.save),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: spaceM),
        children: [
          if (widget.path case final path?)
            Padding(
              padding: const EdgeInsets.all(spaceM),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(path),
                  height: 220,
                  fit: BoxFit.cover,
                  cacheWidth: 1000,
                  errorBuilder: (_, _, _) =>
                      SizedBox(height: 220, child: ColoredBox(color: nb.mist)),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceM),
              child: Column(
                children: [
                  Text(errorText(l, _error!), textAlign: TextAlign.center),
                  TextButton(onPressed: _estimate, child: Text(l.tryAgain)),
                ],
              ),
            )
          else if (items == null)
            Padding(
              padding: const EdgeInsets.all(spaceM),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l.mealReading),
                ],
              ),
            )
          else ...[
            if (widget.path != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceM),
                child: Text(
                  l.mealHint,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
            ListTile(
              key: const ValueKey('meal-time'),
              leading: const Icon(Icons.schedule),
              title: Text(l.mealTime),
              trailing: Text(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(_at)),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              onTap: _pickTime,
            ),
            for (var i = 0; i < items.length; i++)
              _DishRow(
                key: _keys[i],
                item: items[i],
                onRename: (name) => _rename(i, name),
                onLess: items[i].eaten > 0.5 ? () => _servings(i, -0.5) : null,
                onMore: items[i].eaten < 20 ? () => _servings(i, 0.5) : null,
                onRemove: () => setState(() {
                  items.removeAt(i);
                  _keys.removeAt(i);
                }),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(l.mealAddDish),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.mealTotal('${total.round()}'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (allMacros)
                    Text(
                      l.mealMacros(
                        '${sum((i) => i.carbsG).round()}',
                        '${sum((i) => i.proteinG).round()}',
                        '${sum((i) => i.fatG).round()}',
                      ),
                      style: text.bodyMedium,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    l.caloriesDisclaimer,
                    style: text.bodySmall?.copyWith(
                      color: nb.inkSoft,
                      fontSize: 11,
                    ),
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

class _DishRow extends StatelessWidget {
  const _DishRow({
    super.key,
    required this.item,
    required this.onRename,
    required this.onLess,
    required this.onMore,
    required this.onRemove,
  });

  final MealItem item;
  final ValueChanged<String> onRename;
  final VoidCallback? onLess;
  final VoidCallback? onMore;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final kcal = item.kcal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceXs, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.name,
                  autofocus: item.name.isEmpty,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l.mealDishName,
                    isDense: true,
                  ),
                  onFieldSubmitted: onRename,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onChanged: onRename,
                ),
              ),
              IconButton(
                tooltip: l.remove,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: onLess,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                l.mealServings(_MealPageState._num(item.eaten)),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.add_circle_outline),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: spaceS),
                  child: Text(
                    textAlign: TextAlign.end,
                    kcal == null
                        ? l.mealUnknownKcal
                        : l.caloriesKcal('${(kcal * item.eaten).round()}'),
                    style: kcal == null
                        ? text.bodySmall?.copyWith(color: nb.inkSoft)
                        : text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
