import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Owner > one ingredient, to read: its category and lines, then tabs: its other names, and the ingredients that may
/// be the same food (each opens its page). Edit (the pencil) changes it: owner_ingredient_edit_page.dart.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<OwnerRepository>().ingredientDetail(
        widget.id,
      );
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final soft = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: nb.inkSoft);
    final d = _d;
    Widget note(String text) => Padding(
      padding: const EdgeInsets.all(spaceM),
      child: Text(text, style: soft),
    );
    Widget row(Widget tile) => Padding(
      padding: const EdgeInsets.only(bottom: spaceXs),
      child: tile,
    );
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
              onPressed: () async {
                await context.push('/owner/ingredient/${d.id}/edit');
                _load(); // a new name, another name, a split
              },
            ),
        ],
      ),
      body: LoadView(
        loading: _loading && d == null,
        error: _error,
        onReload: _load,
        child: d == null
            ? null
            : DetailTabs(
                header: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      spaceM,
                      0,
                      spaceM,
                      spaceS,
                    ),
                    child: Wrap(
                      spacing: spaceXs,
                      runSpacing: spaceXs,
                      children: [
                        TagChip(
                          TileTag(d.category ?? l.ownerIngredientNoCategory),
                        ),
                        TagChip(
                          TileTag(
                            l.ownerGapCount(d.recipeLines, d.shoppingLines),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                sections: [
                  DetailSection(
                    id: 'ingredient-tab-aliases',
                    label: l.ownerIngredientAliases,
                    rows: [
                      if (d.aliases.isEmpty) note(l.ownerIngredientNoAliases),
                      for (final a in d.aliases)
                        row(
                          BaseTile(
                            key: ValueKey('alias-$a'),
                            dense: true,
                            title: a,
                          ),
                        ),
                    ],
                  ),
                  DetailSection(
                    id: 'ingredient-tab-similar',
                    label: l.ownerIngredientSimilar,
                    rows: [
                      if (d.similar.isEmpty) note(l.ownerIngredientNoSimilar),
                      for (final s in d.similar)
                        row(
                          BaseTile(
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
                ],
              ),
      ),
    );
  }
}
