import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';

/// Edits a recipe: its name, then one row per ingredient (amount, unit, ingredient) and per step. Drag to reorder;
/// Enter starts the next row and moves the cursor there; a pasted list splits into rows. The API still takes one line
/// per ingredient ("2 cawan tepung gandum"): the rows are joined back and the server reads amount and unit from it.
/// A row left as it was is sent exactly as stored, so its catalogue link stays. Pops the saved recipe.
/// No [recipe] = a new one typed from scratch (POST /recipes), starting with one empty row in each section.

/// The units the shopping list adds up and converts (bukuresipi-hono shopping/amounts.ts), in the order a cook
/// reaches for them.
const recipeUnits = [
  'g', 'kg', 'ml', 'l', 'cawan', 'sudu besar', 'sudu kecil', //
  'biji',
  'ulas',
  'batang',
  'helai',
  'keping',
  'tangkai',
  'labu',
  'inci',
  'cm',
  'tin',
  'paket',
  'bungkus',
  'genggam', 'cubit',
];

// Other spellings the server also reads as a unit (UNIT_ALIASES): kept as typed in a line we load.
const _unitAliases = {
  'gram',
  'grams',
  'gm',
  'gr',
  'kilo',
  'kilogram',
  'liter',
  'litre',
  'mililiter',
  'millilitre', //
  'sb', 'tbsp', 'sk', 'tsp', 'cwn', 'cup', 'cups',
};

final _quantity = RegExp(
  r'^(\d+(?:[.,]\d+)?(?:/\d+)?(?:-\d+(?:[.,]\d+)?)?|[½¼¾⅓⅔])$',
);

bool _isUnit(String s) {
  final k = s.toLowerCase().replaceAll(RegExp(r'\.$'), '');
  return recipeUnits.contains(k) || _unitAliases.contains(k);
}

/// A line as the server's splitAmount reads it: up to two amount words, then a known unit (two words first), then
/// the ingredient. "1 1/2 cawan tepung" -> ("1 1/2", "cawan", "tepung"); "garam secukupnya" -> ("", null, ...).
({String amount, String? unit, String name}) splitLine(String line) {
  final words = line
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  var n = 0;
  while (n < 2 && n < words.length && _quantity.hasMatch(words[n])) {
    n++;
  }
  if (n == 0) return (amount: '', unit: null, name: words.join(' '));
  final two = words.length >= n + 2 ? '${words[n]} ${words[n + 1]}' : null;
  final unitWords = two != null && _isUnit(two)
      ? 2
      : words.length > n && _isUnit(words[n])
      ? 1
      : 0;
  return (
    amount: words.take(n).join(' '),
    unit: unitWords == 0 ? null : words.skip(n).take(unitWords).join(' '),
    name: words.skip(n + unitWords).join(' '),
  );
}

/// The one line the API takes for a row.
String joinLine(String amount, String? unit, String name) => [
  amount.trim(),
  unit?.trim() ?? '',
  name.trim(),
].where((s) => s.isNotEmpty).join(' ');

/// The word being typed at the end of an ingredient ("tepung ga" -> "ga"); null when it ends in a space, a number or
/// punctuation, or the word is under 2 letters.
String? typingWord(String line) =>
    RegExp(r'(\p{L}{2,})$', unicode: true).firstMatch(line)?.group(1);

/// [line] with its trailing words that belong to the catalogue [name] replaced by it:
/// ("tepung ga", "Tepung gandum") -> "tepung gandum"; words before it are kept ("2 cawan tepung ga" too).
String completeLine(String line, String name) {
  final parts = name.toLowerCase().split(' ');
  final words = line.split(' ');
  var keep = words.length;
  while (keep > 0) {
    final w = words[keep - 1].toLowerCase();
    if (w.isEmpty || !parts.any((p) => p.startsWith(w))) break;
    keep--;
  }
  return [...words.take(keep), name.toLowerCase()].join(' ');
}

const _maxRows = 100; // the API's limit per section

/// One ingredient row: amount, unit, ingredient. [original] = the stored line it was loaded from.
class _Ingredient {
  _Ingredient({String amount = '', this.unit, String name = '', this.original})
    : amount = TextEditingController(text: amount),
      name = TextEditingController(text: name);

  factory _Ingredient.fromLine(String line, {bool stored = false}) {
    final s = splitLine(line);
    return _Ingredient(
      amount: s.amount,
      unit: s.unit,
      name: s.name,
      original: stored ? line : null,
    );
  }

  final TextEditingController amount;
  String? unit;
  final TextEditingController name;
  final String? original;
  final amountFocus = FocusNode();
  final nameFocus = FocusNode();
  bool nameMissing = false;

  bool get isEmpty =>
      amount.text.trim().isEmpty && unit == null && name.text.trim().isEmpty;

  String get line => joinLine(amount.text, unit, name.text);

  /// Untouched = the stored line word for word (the server then keeps its amount, unit and link).
  String get sent {
    final o = original;
    return o != null &&
            joinLine(
                  splitLine(o).amount,
                  splitLine(o).unit,
                  splitLine(o).name,
                ) ==
                line
        ? o.trim()
        : line;
  }

  void dispose() {
    amount.dispose();
    name.dispose();
    amountFocus.dispose();
    nameFocus.dispose();
  }
}

class _Step {
  _Step([String text = '']) : text = TextEditingController(text: text);

  final TextEditingController text;
  final focus = FocusNode();

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class RecipeEditPage extends StatefulWidget {
  const RecipeEditPage({super.key, this.recipe});

  final RecipeDetail? recipe;

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  late final _name = TextEditingController(text: widget.recipe?.name);
  late final List<_Ingredient> _ingredients = switch (widget.recipe) {
    final r? when r.ingredients.isNotEmpty => [
      for (final i in r.ingredients)
        _Ingredient.fromLine(i.rawText ?? i.label, stored: true),
    ],
    _ => [_Ingredient()],
  };
  late final List<_Step> _steps = switch (widget.recipe) {
    final r? when r.steps.isNotEmpty => [
      for (final s in r.steps) _Step(s.instruction),
    ],
    _ => [_Step()],
  };
  // Removed rows: disposed with the page, not while their fields may still be mounted this frame.
  final _gone = <Object>[];
  late final String _initial = _snapshot();
  bool _saving = false;
  bool _nameMissing = false;

  // Catalogue suggestions under the ingredient being typed (GET /recipes/ingredients), so the line gets linked.
  _Ingredient? _suggestFor;
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _query = 0;

  @override
  void initState() {
    super.initState();
    _initial; // taken before any edit
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    for (final r in [..._ingredients, ..._gone.whereType<_Ingredient>()]) {
      r.dispose();
    }
    for (final s in [..._steps, ..._gone.whereType<_Step>()]) {
      s.dispose();
    }
    super.dispose();
  }

  String _snapshot() => [
    _name.text.trim(),
    for (final r in _ingredients) r.line,
    '|',
    for (final s in _steps) s.text.text.trim(),
  ].join('\n');

  bool get _dirty => _snapshot() != _initial;

  /// After the frame that builds the row: a field asked for focus before it exists is ignored.
  void _focusLater(FocusNode node) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });

  // ----- ingredients

  void _addIngredient({int? after, _Ingredient? row}) {
    if (_ingredients.length >= _maxRows) return;
    final fresh = row ?? _Ingredient();
    setState(
      () => _ingredients.insert(
        after == null ? _ingredients.length : after + 1,
        fresh,
      ),
    );
    _focusLater(fresh.nameFocus);
  }

  /// Enter on an ingredient or its amount: the next row (made when this is the last one), cursor in its ingredient.
  void _nextIngredient(_Ingredient row) {
    final i = _ingredients.indexOf(row);
    if (i < _ingredients.length - 1) {
      return _ingredients[i + 1].nameFocus.requestFocus();
    }
    if (row.isEmpty) return; // Enter on an empty last row: nothing to start
    _addIngredient(after: i);
  }

  /// A pasted list ("2 cawan tepung\n3 biji telur"): this row keeps the first line, each other line is a new row.
  void _pastedIngredients(_Ingredient row, String value) {
    final parts = value.split('\n').map((p) => p.trim()).toList();
    final first = splitLine(parts.first);
    final fresh = [
      for (final p in parts.skip(1))
        if (p.isNotEmpty) _Ingredient.fromLine(p),
    ];
    setState(() {
      if (row.amount.text.trim().isEmpty &&
          row.unit == null &&
          first.amount.isNotEmpty) {
        row.amount.text = first.amount;
        row.unit = first.unit;
        row.name.text = first.name;
      } else {
        row.name.text = parts.first;
      }
      final room = _maxRows - _ingredients.length;
      _ingredients.insertAll(_ingredients.indexOf(row) + 1, fresh.take(room));
    });
    _focusLater((fresh.isEmpty ? row : fresh.last).nameFocus);
  }

  void _removeIngredient(_Ingredient row) => setState(() {
    _ingredients.remove(row);
    _gone.add(row);
    if (_suggestFor == row) _suggestions = const [];
  });

  void _suggest(_Ingredient row) {
    _debounce?.cancel();
    final word = typingWord(row.name.text);
    if (word == null) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final mine = ++_query;
      try {
        final names = await context.read<RecipesController>().searchIngredients(
          word,
        );
        if (!mounted || mine != _query) return;
        setState(() {
          _suggestFor = row;
          _suggestions = names.take(5).toList();
        });
      } catch (_) {
        // A hint only: typing goes on without it.
      }
    });
  }

  void _pick(_Ingredient row, String name) {
    final text = completeLine(row.name.text, name);
    row.name.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _suggestions = const []);
  }

  // ----- steps

  void _addStep({int? after, _Step? step}) {
    if (_steps.length >= _maxRows) return;
    final fresh = step ?? _Step();
    setState(
      () => _steps.insert(after == null ? _steps.length : after + 1, fresh),
    );
    _focusLater(fresh.focus);
  }

  void _nextStep(_Step step) {
    final i = _steps.indexOf(step);
    if (i < _steps.length - 1) return _steps[i + 1].focus.requestFocus();
    if (step.text.text.trim().isEmpty) return;
    _addStep(after: i);
  }

  void _pastedSteps(_Step step, String value) {
    final parts = value.split('\n').map((p) => p.trim()).toList();
    final fresh = [
      for (final p in parts.skip(1))
        if (p.isNotEmpty) _Step(p),
    ];
    setState(() {
      step.text.text = parts.first;
      _steps.insertAll(
        _steps.indexOf(step) + 1,
        fresh.take(_maxRows - _steps.length),
      );
    });
    _focusLater((fresh.isEmpty ? step : fresh.last).focus);
  }

  void _removeStep(_Step step) => setState(() {
    _steps.remove(step);
    _gone.add(step);
  });

  // ----- save / leave

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    // An amount or unit with no ingredient would save as "2 cawan": ask for the ingredient instead.
    final nameless = [
      for (final r in _ingredients)
        if (!r.isEmpty && r.name.text.trim().isEmpty) r,
    ];
    setState(() {
      _nameMissing = name.isEmpty;
      for (final r in _ingredients) {
        r.nameMissing = nameless.contains(r);
      }
    });
    if (name.isEmpty) return;
    if (nameless.isNotEmpty) return nameless.first.nameFocus.requestFocus();
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ingredients = [
      for (final r in _ingredients)
        if (!r.isEmpty) r.sent,
    ];
    final steps = [
      for (final s in _steps)
        if (s.text.text.trim().isNotEmpty) s.text.text.trim(),
    ];
    try {
      final recipes = context.read<RecipesController>();
      final saved = switch (widget.recipe) {
        final r? => await recipes.edit(
          r.id,
          name: name,
          ingredients: ingredients,
          steps: steps,
        ),
        null => await recipes.create(
          name: name,
          ingredients: ingredients,
          steps: steps,
        ),
      };
      navigator.pop(saved);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final sure = await showNotebookDialog(
      context,
      message: l.recipeEditDiscard,
      tone: DialogTone.danger,
      confirmLabel: l.recipeEditDiscardOk,
    );
    if (sure && mounted) navigator.pop();
  }

  // ----- build

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _addButton(String label, VoidCallback? onPressed) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    ),
  );

  Widget _ingredientRow(int i, _Ingredient r) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return Column(
      key: ObjectKey(r),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 8, 8),
                child: Icon(Icons.drag_indicator, color: nb.inkSoft),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    key: ValueKey('ingredient-name-$i'),
                    controller: r.name,
                    focusNode: r.nameFocus,
                    maxLines: null,
                    maxLength: 250,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: l.recipeEditIngredientHint,
                      counterText: '',
                      errorText: r.nameMissing
                          ? l.recipeEditIngredientRequired
                          : null,
                    ),
                    onChanged: (v) {
                      if (v.contains('\n')) return _pastedIngredients(r, v);
                      setState(
                        () => r.nameMissing = r.nameMissing && v.trim().isEmpty,
                      );
                      _suggest(r);
                    },
                    onSubmitted: (_) => _nextIngredient(r),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 88,
                        child: TextField(
                          key: ValueKey('ingredient-amount-$i'),
                          controller: r.amount,
                          focusNode: r.amountFocus,
                          maxLength: 12,
                          // The date keyboard has digits with / and -: fractions (1/2) and ranges (2-3) in one tap.
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,/\- ½¼¾⅓⅔]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: l.recipeEditAmount,
                            counterText: '',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _nextIngredient(r),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _UnitPicker(
                        key: ValueKey('ingredient-unit-$i'),
                        unit: r.unit,
                        onChanged: (u) => setState(() => r.unit = u),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l.remove,
              icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
              onPressed: () => _removeIngredient(r),
            ),
          ],
        ),
        if (r == _suggestFor && _suggestions.isNotEmpty)
          _Suggestions(
            names: _suggestions,
            typed: typingWord(r.name.text) ?? '',
            onPick: (name) => _pick(r, name),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stepRow(int i, _Step s) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return Row(
      key: ObjectKey(s),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableDragStartListener(
          index: i,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator, color: nb.inkSoft),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: nb.hand.copyWith(fontSize: 20, color: nb.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TextField(
            key: ValueKey('step-$i'),
            controller: s.text,
            focusNode: s.focus,
            maxLines: null,
            maxLength: 2000,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l.recipeEditStepHint,
              counterText: '',
            ),
            onChanged: (v) =>
                v.contains('\n') ? _pastedSteps(s, v) : setState(() {}),
            onSubmitted: (_) => _nextStep(s),
          ),
        ),
        IconButton(
          tooltip: l.remove,
          icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
          onPressed: () => _removeStep(s),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: _saving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          title: NotebookTitle(
            widget.recipe == null ? l.recipeNew : l.recipeEdit,
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(onPressed: _save, child: Text(l.save)),
          ],
        ),
        body: NotebookPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 12, 32),
            children: [
              TextField(
                controller: _name,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.recipeEditName,
                  errorText: _nameMissing ? l.recipeEditNameRequired : null,
                ),
                onChanged: (v) => setState(
                  () => _nameMissing = _nameMissing && v.trim().isEmpty,
                ),
                onSubmitted: (_) => _ingredients.isEmpty
                    ? _addIngredient()
                    : _ingredients.first.nameFocus.requestFocus(),
              ),
              _heading(l.recipeIngredients),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => setState(
                  () => _ingredients.insert(to, _ingredients.removeAt(from)),
                ),
                children: [
                  for (final (i, r) in _ingredients.indexed)
                    _ingredientRow(i, r),
                ],
              ),
              _addButton(
                l.recipeEditAddIngredient,
                _ingredients.length < _maxRows ? () => _addIngredient() : null,
              ),
              _heading(l.recipeSteps),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) =>
                    setState(() => _steps.insert(to, _steps.removeAt(from))),
                children: [for (final (i, s) in _steps.indexed) _stepRow(i, s)],
              ),
              _addButton(
                l.recipeEditAddStep,
                _steps.length < _maxRows ? () => _addStep() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The unit beside an amount: a compact menu of [recipeUnits] (plus a stored spelling such as "sb"), or none.
class _UnitPicker extends StatelessWidget {
  const _UnitPicker({super.key, required this.unit, required this.onChanged});

  final String? unit;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final options = [
      if (unit != null && !recipeUnits.contains(unit)) unit!,
      ...recipeUnits,
    ];
    return PopupMenuButton<String>(
      tooltip: l.recipeEditUnit,
      initialValue: unit ?? '',
      onSelected: (u) => onChanged(u.isEmpty ? null : u),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          child: Text(l.recipeEditNoUnit, style: TextStyle(color: nb.inkSoft)),
        ),
        for (final u in options) PopupMenuItem(value: u, child: Text(u)),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: nb.line)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unit ?? l.recipeEditUnit,
              style: TextStyle(color: unit == null ? nb.inkSoft : null),
            ),
            Icon(Icons.arrow_drop_down, color: nb.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// The autocomplete list under an ingredient row: a raised paper card attached to the field, one row per catalogue
/// match with the typed part in bold, the best match first (as the server sorts them).
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.names,
    required this.typed,
    required this.onPick,
  });

  final List<String> names;
  final String typed;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 2, 48, 8),
      child: Material(
        color: nb.paper,
        elevation: 3,
        shadowColor: nb.ink.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: nb.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: Text(
                l.recipeEditSuggestions,
                style: text.labelSmall?.copyWith(
                  color: nb.inkSoft,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final (i, name) in names.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 44, color: nb.rule),
              InkWell(
                key: ValueKey('suggest-$name'),
                onTap: () => onPick(name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.eco_outlined, size: 18, color: nb.pandan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _bolded(
                          name.toLowerCase(),
                          typed.toLowerCase(),
                          text.bodyLarge,
                          nb,
                        ),
                      ),
                      Icon(Icons.north_west, size: 16, color: nb.inkSoft),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _bolded(
    String name,
    String typed,
    TextStyle? style,
    Notebook nb,
  ) {
    final at = typed.isEmpty ? -1 : name.indexOf(typed);
    if (at < 0) {
      return Text(
        name,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: name.substring(0, at)),
          TextSpan(
            text: name.substring(at, at + typed.length),
            style: TextStyle(fontWeight: FontWeight.w800, color: nb.pandanDeep),
          ),
          TextSpan(text: name.substring(at + typed.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
