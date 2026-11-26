import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../widgets/alias_suggest_sheet.dart';
import '../widgets/ingredient_gap_sheet.dart';

/// Owner > Ingredient gaps: lines no catalogue name matched; a tap adds the alias or ingredient we lack and every
/// unlinked line is matched again. Server design: bukuresipi-hono docs/superpowers/specs/2026-11-26-ingredient-gaps-design.md.
class OwnerIngredientsPage extends StatefulWidget {
  const OwnerIngredientsPage({super.key});

  @override
  State<OwnerIngredientsPage> createState() => _OwnerIngredientsPageState();
}

class _OwnerIngredientsPageState extends State<OwnerIngredientsPage> {
  List<IngredientGap>? _gaps;
  List<String> _categories = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<OwnerRepository>().ingredientGaps();
      if (mounted) {
        setState(() {
          _gaps = r.gaps;
          _categories = r.categories;
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

  Future<void> _open(IngredientGap gap) async {
    final l = AppLocalizations.of(context);
    final linked = await showBaseSheet<int>(
      context,
      builder: (_) => IngredientGapSheet(gap: gap, categories: _categories),
    );
    if (linked == null || !mounted) return;
    _snack(l.ownerGapSaved(linked));
    _load();
  }

  Future<void> _relink() async {
    final l = AppLocalizations.of(context);
    try {
      final r = await context.read<OwnerRepository>().relinkIngredients();
      if (!mounted) return;
      _snack(l.ownerRelinked(r.linked, r.checked));
      _load();
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    }
  }

  Future<void> _suggestAliases() async {
    final l = AppLocalizations.of(context);
    final done = await showBaseSheet<(int, int)>(
      context,
      floating: false, // a long list to tick
      builder: (_) => const AliasSuggestSheet(),
    );
    if (done == null || !mounted) return;
    _snack(l.ownerAliasAiSaved(done.$1, done.$2));
    _load();
  }

  Future<void> _copyRows() async {
    final l = AppLocalizations.of(context);
    try {
      final rows = await context.read<OwnerRepository>().addedIngredientRows();
      if (!mounted) return;
      await showBaseSheet<void>(context, builder: (_) => _RowsSheet(rows));
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final gaps = _gaps;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerIngredientGaps),
        actions: [
          IconButton(
            key: const ValueKey('gaps-more'),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert),
            onPressed: () => showActionSheet(
              context,
              actions: [
                MenuAction(
                  icon: Icons.auto_awesome,
                  label: l.ownerAliasAiTitle,
                  onTap: _suggestAliases,
                ),
                MenuAction(
                  icon: Icons.link,
                  label: l.ownerRelink,
                  onTap: _relink,
                ),
                MenuAction(
                  icon: Icons.content_copy,
                  label: l.ownerCopyRows,
                  onTap: _copyRows,
                ),
              ],
            ),
          ),
        ],
      ),
      body: WidePage(
        child: LoadView(
          loading: _loading,
          error: _error,
          onReload: _load,
          child: gaps == null
              ? null
              : ListView(
                  padding: const EdgeInsets.only(bottom: spaceL),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: spaceM),
                      child: Text(
                        gaps.isEmpty
                            ? l.ownerNoGaps
                            : l.ownerIngredientGapsHint,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ),
                    const SizedBox(height: spaceS),
                    for (final g in gaps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: spaceXs),
                        child: BaseTile(
                          key: ValueKey('gap-${g.key}'),
                          title: g.key,
                          subtitle:
                              '${l.ownerGapCount(g.recipeLines, g.shoppingLines)}\n${g.sample}',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(g),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The rows added in the app, to paste into docs/plans/ (the seed for new and test databases).
class _RowsSheet extends StatelessWidget {
  const _RowsSheet(this.rows);

  final ({String ingredients, String aliases}) rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    Widget block(String file, String rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(file, style: text.titleSmall)),
            IconButton(
              tooltip: l.ownerCopyRows,
              icon: const Icon(Icons.content_copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: rows));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.ownerCopied)));
                }
              },
            ),
          ],
        ),
        SelectableText(
          rows,
          style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: spaceM),
      ],
    );
    final none = rows.ingredients.isEmpty && rows.aliases.isEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.ownerCopyRows, style: text.titleMedium),
          const SizedBox(height: spaceXs),
          Text(
            none ? l.ownerCopyRowsNone : l.ownerCopyRowsHint,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: spaceS),
          if (rows.ingredients.isNotEmpty)
            block('ingredient.md', rows.ingredients),
          if (rows.aliases.isNotEmpty)
            block('ingredient_alias.md', rows.aliases),
        ],
      ),
    );
  }
}
