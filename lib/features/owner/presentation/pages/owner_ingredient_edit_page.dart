import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Edit ingredient, in tabs as Edit branch: Details (name and category, saved with the check, which goes back) and
/// Other names (add one; remove a wrong one; make a kind its own ingredient: "limau nipis" off Limau). A name's
/// change is saved at once, after a dialog with how many lines it moves.
class OwnerIngredientEditPage extends StatefulWidget {
  const OwnerIngredientEditPage({super.key, required this.id});

  final int id;

  @override
  State<OwnerIngredientEditPage> createState() =>
      _OwnerIngredientEditPageState();
}

class _OwnerIngredientEditPageState extends State<OwnerIngredientEditPage> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  IngredientDetail? _d;
  List<String> _categories = const [];
  Object? _error;
  Object? _saveError;
  bool _loading = true;
  bool _saving = false;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _load(fields: true);
    _repo.listIngredients().then((rows) {
      if (mounted) {
        setState(
          () =>
              _categories = {for (final r in rows) ?r.category}.toList()
                ..sort(),
        );
      }
    }, onError: (_) {}); // offline: the category is typed
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  /// [fields]: the first read fills the form; later reads (after a name's change) keep what was typed.
  Future<void> _load({bool fields = false}) async {
    setState(() => _loading = true);
    try {
      final d = await _repo.ingredientDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _d = d;
        _error = null;
        if (fields) {
          _name.text = d.name;
          _category.text = d.category ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(IngredientDetail d) async {
    final name = _name.text.trim();
    final category = _category.text.trim();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (name != d.name || (category.isNotEmpty && category != d.category)) {
        await _repo.updateIngredient(
          d.id,
          name: name == d.name ? null : name,
          category: category.isEmpty || category == d.category
              ? null
              : category,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _saveError = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Asks with the preview's count, then does it and reads the page again.
  Future<void> _aliasAction(
    String alias, {
    required Future<({int lines, List<String> sample})> Function() preview,
    required String Function(int lines) ask,
    required String confirm,
    required DialogTone tone,
    required Future<String> Function() run,
  }) async {
    final l = AppLocalizations.of(context);
    try {
      final p = await preview();
      if (!mounted) return;
      final sample = p.sample.take(5).map((s) => '• $s').join('\n');
      final ok = await showBaseDialog(
        context,
        message: sample.isEmpty ? ask(p.lines) : '${ask(p.lines)}\n\n$sample',
        tone: tone,
        confirmLabel: confirm,
      );
      if (!ok || !mounted) return;
      _snack(await run());
      await _load();
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    }
  }

  void _remove(String alias) {
    final l = AppLocalizations.of(context);
    _aliasAction(
      alias,
      preview: () => _repo.previewRemoveAlias(widget.id, alias),
      ask: (n) => l.ownerIngredientRemoveAsk(alias, n),
      confirm: l.ownerIngredientRemoveAlias,
      tone: DialogTone.danger,
      run: () async =>
          l.ownerIngredientRemoved(await _repo.removeAlias(widget.id, alias)),
    );
  }

  void _split(String alias) {
    final l = AppLocalizations.of(context);
    _aliasAction(
      alias,
      preview: () => _repo.previewSplitAlias(widget.id, alias),
      ask: (n) => l.ownerIngredientSplitAsk(alias, n),
      confirm: l.ownerIngredientSplitAlias,
      tone: DialogTone.confirm,
      run: () async {
        final made = await _repo.splitAlias(widget.id, alias);
        return l.ownerIngredientSplitDone(made.name, made.moved);
      },
    );
  }

  Future<void> _addAlias(IngredientDetail d) async {
    final linked = await showBaseSheet<int>(
      context,
      builder: (_) => _AliasSheet(ingredient: d.name),
    );
    if (linked == null || !mounted) return;
    _snack(AppLocalizations.of(context).ownerGapSaved(linked));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final soft = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: nb.inkSoft);
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerIngredientEdit),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(spaceM),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (d != null)
            IconButton(
              key: const ValueKey('ingredient-save'),
              tooltip: l.save,
              icon: const Icon(Icons.check),
              onPressed: _name.text.trim().length >= 2 ? () => _save(d) : null,
            ),
        ],
      ),
      body: LoadView(
        loading: _loading && d == null,
        error: d == null ? _error : null,
        onReload: () => _load(fields: true),
        child: d == null
            ? null
            : GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: EditTabs(
                  sections: [
                    DetailSection(
                      id: 'ingredient-edit-details',
                      label: l.ownerIngredientTabDetails,
                      rows: [
                        Padding(
                          padding: const EdgeInsets.all(spaceM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                key: const ValueKey('ingredient-name'),
                                controller: _name,
                                maxLength: 60,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: l.ownerIngredientName,
                                  helperText: l.ownerIngredientRenameNote,
                                  helperMaxLines: 3,
                                ),
                              ),
                              const SizedBox(height: spaceS),
                              PickerField(
                                controller: _category,
                                label: l.ownerGapCategory,
                                options: _categories,
                                onPicked: (_) => setState(() {}),
                              ),
                              if (_saveError case final e?)
                                Padding(
                                  padding: const EdgeInsets.only(top: spaceS),
                                  child: Text(
                                    errorText(l, e),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    DetailSection(
                      id: 'ingredient-edit-aliases',
                      label: l.ownerIngredientAliases,
                      rows: [
                        Padding(
                          padding: const EdgeInsets.all(spaceM),
                          child: Text(
                            d.aliases.isEmpty
                                ? l.ownerIngredientNoAliases
                                : l.ownerIngredientAliasesHint,
                            style: soft,
                          ),
                        ),
                        for (final a in d.aliases)
                          Padding(
                            padding: const EdgeInsets.only(bottom: spaceXs),
                            child: BaseTile(
                              key: ValueKey('alias-$a'),
                              dense: true,
                              title: a,
                              actions: [
                                MenuAction(
                                  icon: Icons.call_split,
                                  label: l.ownerIngredientSplitAlias,
                                  onTap: () => _split(a),
                                ),
                                MenuAction(
                                  icon: Icons.delete_outline,
                                  label: l.ownerIngredientRemoveAlias,
                                  danger: true,
                                  onTap: () => _remove(a),
                                ),
                              ],
                            ),
                          ),
                        BaseTile(
                          key: const ValueKey('alias-add'),
                          dense: true,
                          leading: const Icon(Icons.add),
                          title: l.ownerIngredientAddAlias,
                          onTap: () => _addAlias(d),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Another name for [ingredient]: saved, then every unlinked line is matched again. Pops how many it linked.
class _AliasSheet extends StatefulWidget {
  const _AliasSheet({required this.ingredient});

  final String ingredient;

  @override
  State<_AliasSheet> createState() => _AliasSheetState();
}

class _AliasSheetState extends State<_AliasSheet> {
  final _alias = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final linked = await context.read<OwnerRepository>().addAlias(
        widget.ingredient,
        _alias.text.trim().toLowerCase(),
      );
      if (mounted) Navigator.pop(context, linked);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.ownerIngredientAddAlias,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(widget.ingredient, style: TextStyle(color: nb.inkSoft)),
          const SizedBox(height: spaceM),
          TextField(
            key: const ValueKey('alias-new'),
            controller: _alias,
            autofocus: true,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.ownerIngredientName),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: spaceS),
              child: Text(
                errorText(l, e),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: spaceM),
          PanelActions(
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text(l.cancel, style: TextStyle(color: nb.inkSoft)),
              ),
              BusyButton(
                key: const ValueKey('alias-save'),
                kind: BusyButtonKind.filled,
                icon: Icons.check,
                label: l.save,
                busyLabel: l.save,
                busy: _busy,
                onPressed: _alias.text.trim().length >= 2 && !_busy
                    ? _save
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
