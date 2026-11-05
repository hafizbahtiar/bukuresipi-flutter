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
class RecipeEditPage extends StatefulWidget {
  const RecipeEditPage({super.key, required this.recipe});

  final RecipeDetail recipe;

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  late final _name = TextEditingController(text: widget.recipe.name);
  late final _ingredients = [
    for (final i in widget.recipe.ingredients)
      TextEditingController(text: i.rawText ?? i.label),
  ];
  late final _steps = [
    for (final s in widget.recipe.steps)
      TextEditingController(text: s.instruction),
  ];
  // Removed rows: disposed with the page, not while their field may still be mounted this frame.
  final _gone = <TextEditingController>[];
  TextEditingController? _fresh; // a row just made: it takes the focus
  bool _saving = false;
  bool _nameMissing = false;

  @override
  void dispose() {
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

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    setState(() => _nameMissing = name.isEmpty);
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await context.read<RecipesController>().edit(
        widget.recipe.id,
        name: name,
        ingredients: _lines(_ingredients),
        steps: _lines(_steps),
      );
      navigator.pop(saved);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _section(
    String title,
    String addLabel,
    List<TextEditingController> rows,
  ) {
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
            Row(
              key: ObjectKey(c),
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
                    onChanged: (v) => _split(rows, i, v),
                  ),
                ),
                IconButton(
                  tooltip: l.remove,
                  icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
                  onPressed: () => setState(() => _gone.add(rows.removeAt(i))),
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
        title: NotebookTitle(l.recipeEdit),
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
            ),
            ..._section(l.recipeSteps, l.recipeEditAddStep, _steps),
          ],
        ),
      ),
    );
  }
}
