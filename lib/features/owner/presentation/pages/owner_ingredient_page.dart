import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Owner > one ingredient: its name and category (Edit), its other names (add; remove a wrong one; make a kind its
/// own ingredient: "limau nipis" off Limau), and the ingredients that may be the same food (each opens its page).
class OwnerIngredientPage extends StatefulWidget {
  const OwnerIngredientPage({super.key, required this.id});

  final int id;

  @override
  State<OwnerIngredientPage> createState() => _OwnerIngredientPageState();
}

class _OwnerIngredientPageState extends State<OwnerIngredientPage> {
  IngredientDetail? _d;
  Object? _error;
  bool _loading = true;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _repo.ingredientDetail(widget.id);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _edit(IngredientDetail d) async {
    List<String> categories = const [];
    try {
      categories = {
        for (final r in await _repo.listIngredients()) ?r.category,
      }.toList()..sort();
    } catch (_) {
      // Offline: the sheet still renames; the save says why if it fails.
    }
    if (!mounted) return;
    final saved = await showBaseSheet<IngredientDetail>(
      context,
      builder: (_) => _EditSheet(detail: d, categories: categories),
    );
    // The title shows it.
    if (saved != null && mounted) {
      setState(() => _d = saved);
    }
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
    final text = Theme.of(context).textTheme;
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(d?.name ?? l.ownerIngredientsShort),
        actions: [
          if (d != null)
            IconButton(
              key: const ValueKey('ingredient-edit'),
              tooltip: l.ownerIngredientEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(d),
            ),
        ],
      ),
      body: WidePage(
        child: LoadView(
          loading: _loading && d == null,
          error: _error,
          onReload: _load,
          child: d == null
              ? null
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: spaceL),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: spaceM),
                        child: Wrap(
                          spacing: spaceXs,
                          runSpacing: spaceXs,
                          children: [
                            TagChip(
                              TileTag(
                                d.category ?? l.ownerIngredientNoCategory,
                              ),
                            ),
                            TagChip(
                              TileTag(
                                l.ownerGapCount(d.recipeLines, d.shoppingLines),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SectionHeader(l.ownerIngredientAliases),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          spaceM,
                          0,
                          spaceM,
                          spaceS,
                        ),
                        child: Text(
                          d.aliases.isEmpty
                              ? l.ownerIngredientNoAliases
                              : l.ownerIngredientAliasesHint,
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
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
                      SectionHeader(l.ownerIngredientSimilar),
                      if (d.similar.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: spaceM,
                          ),
                          child: Text(
                            l.ownerIngredientNoSimilar,
                            style: text.bodySmall?.copyWith(color: nb.inkSoft),
                          ),
                        ),
                      for (final s in d.similar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: spaceXs),
                          child: BaseTile(
                            key: ValueKey('similar-${s.id}'),
                            dense: true,
                            title: s.name,
                            subtitle: s.category,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push('/owner/ingredient/${s.id}');
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A new name and/or category. Pops the ingredient as saved.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.detail, required this.categories});

  final IngredientDetail detail;
  final List<String> categories;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.detail.name);
  late final _category = TextEditingController(
    text: widget.detail.category ?? '',
  );
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final d = widget.detail;
    final name = _name.text.trim();
    final category = _category.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await context.read<OwnerRepository>().updateIngredient(
        d.id,
        name: name == d.name ? null : name,
        category: category.isEmpty || category == d.category ? null : category,
      );
      if (mounted) Navigator.pop(context, saved);
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
            l.ownerIngredientEdit,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: spaceM),
          TextField(
            key: const ValueKey('ingredient-name'),
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
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
            options: widget.categories,
            onPicked: (_) => setState(() {}),
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
                key: const ValueKey('ingredient-save'),
                kind: BusyButtonKind.filled,
                icon: Icons.check,
                label: l.save,
                busyLabel: l.save,
                busy: _busy,
                onPressed: _name.text.trim().length >= 2 && !_busy
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
