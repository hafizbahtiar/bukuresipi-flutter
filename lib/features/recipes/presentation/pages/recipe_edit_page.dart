import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';

/// Edits a recipe: its name, then one row per ingredient and per step (drag to reorder; Enter or a pasted list splits a
/// row). Amount and unit stay part of the line ("2 cawan gula"): the server reads them. Pops the saved recipe.
/// No [recipe] = a new one typed from scratch (POST /recipes), starting with one empty row in each section.
/// The word being typed at the end of an ingredient line ("2 cawan tep" -> "tep"); null when the line ends in a space,
/// a number or punctuation, or the word is under 2 letters.
String? typingWord(String line) =>
    RegExp(r'(\p{L}{2,})$', unicode: true).firstMatch(line)?.group(1);

/// [line] with its trailing words that belong to the catalogue [name] replaced by it:
/// ("2 cawan tepung ga", "Tepung gandum") -> "2 cawan tepung gandum". Amount and unit are kept as typed.
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

class RecipeEditPage extends StatefulWidget {
  const RecipeEditPage({super.key, this.recipe});

  final RecipeDetail? recipe;

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  late final _name = TextEditingController(text: widget.recipe?.name);
  late final _ingredients = switch (widget.recipe) {
    final r? => [
      for (final i in r.ingredients)
        TextEditingController(text: i.rawText ?? i.label),
    ],
    null => [TextEditingController()],
  };
  late final _steps = switch (widget.recipe) {
    final r? => [
      for (final s in r.steps) TextEditingController(text: s.instruction),
    ],
    null => [TextEditingController()],
  };
  // Removed rows: disposed with the page, not while their field may still be mounted this frame.
  final _gone = <TextEditingController>[];
  TextEditingController? _fresh; // a row just made: it takes the focus
  bool _saving = false;
  bool _nameMissing = false;

  // Catalogue suggestions under the ingredient row being typed (GET /recipes/ingredients), so the line gets linked.
  TextEditingController? _suggestFor;
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _query = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_name, ..._ingredients, ..._steps, ..._gone]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<String> _lines(List<TextEditingController> rows) => [
    for (final c in rows)
      if (c.text.trim().isNotEmpty) c.text.trim(),
  ];

  void _split(List<TextEditingController> rows, int i, String value) {
    if (!value.contains('\n')) return;
    final parts = value.split('\n');
    final added = [
      for (final p in parts.skip(1)) TextEditingController(text: p),
    ];
    setState(() {
      rows[i].text = parts.first;
      rows.insertAll(i + 1, added);
      _fresh = added.last;
    });
  }

  void _suggest(TextEditingController c) {
    _debounce?.cancel();
    final word = typingWord(c.text);
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
          _suggestFor = c;
          _suggestions = names.take(5).toList();
        });
      } catch (_) {
        // A hint only: typing goes on without it.
      }
    });
  }

  void _pick(TextEditingController c, String name) {
    final text = completeLine(c.text, name);
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _suggestions = const []);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    setState(() => _nameMissing = name.isEmpty);
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final recipes = context.read<RecipesController>();
      final saved = switch (widget.recipe) {
        final r? => await recipes.edit(
          r.id,
          name: name,
          ingredients: _lines(_ingredients),
          steps: _lines(_steps),
        ),
        null => await recipes.create(
          name: name,
          ingredients: _lines(_ingredients),
          steps: _lines(_steps),
        ),
      };
      navigator.pop(saved);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _section(
    String title,
    String addLabel,
    List<TextEditingController> rows, {
    bool suggest = false,
  }) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: (from, to) =>
            setState(() => rows.insert(to, rows.removeAt(from))),
        children: [
          for (final (i, c) in rows.indexed)
            Column(
              key: ObjectKey(c),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator, color: nb.inkSoft),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: c,
                        autofocus: c == _fresh,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (v) {
                          _split(rows, i, v);
                          if (suggest) _suggest(c);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: l.remove,
                      icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
                      onPressed: () =>
                          setState(() => _gone.add(rows.removeAt(i))),
                    ),
                  ],
                ),
                if (suggest && c == _suggestFor && _suggestions.isNotEmpty)
                  _Suggestions(
                    names: _suggestions,
                    typed: typingWord(c.text) ?? '',
                    onPick: (name) => _pick(c, name),
                  ),
              ],
            ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            _fresh = TextEditingController();
            rows.add(_fresh!);
          }),
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(
          widget.recipe == null ? l.recipeNew : l.recipeEdit,
        ),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
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
              decoration: InputDecoration(
                labelText: l.recipeEditName,
                errorText: _nameMissing ? l.recipeEditNameRequired : null,
              ),
            ),
            ..._section(
              l.recipeIngredients,
              l.recipeEditAddIngredient,
              _ingredients,
              suggest: true,
            ),
            ..._section(l.recipeSteps, l.recipeEditAddStep, _steps),
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
      padding: const EdgeInsets.fromLTRB(40, 2, 48, 8),
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
