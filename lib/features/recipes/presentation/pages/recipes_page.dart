import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../family/presentation/family_controller.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';
import '../../../shares/presentation/widgets/share_image.dart';

enum RecipeShelf { mine, family, community, catalogue }

/// The Recipes tab: the user's recipes, the family's, the community's and the catalogue dishes, with one search box.
/// Mine and Family are filtered on the phone (already loaded); Community and Catalogue ask the server.
class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _search = TextEditingController();
  RecipeShelf _shelf = RecipeShelf.mine;
  Timer? _debounce;
  String _query = '';

  // Server shelves: the latest answer for _query.
  List<Recipe> _community = const [];
  String? _next;
  List<Dish> _dishes = const [];
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = text.trim());
      _fetch();
    });
  }

  void _pick(RecipeShelf shelf) {
    setState(() => _shelf = shelf);
    _fetch();
  }

  /// Community / Catalogue for the current query; [more] = the next community page.
  Future<void> _fetch({bool more = false}) async {
    if (_shelf != RecipeShelf.community && _shelf != RecipeShelf.catalogue) return;
    final recipes = context.read<RecipesController>();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (_shelf == RecipeShelf.community) {
        final page = await recipes.community(query: _query, cursor: more ? _next : null);
        if (generation != _generation) return;
        _community = more ? [..._community, ...page.recipes] : page.recipes;
        _next = page.next;
      } else {
        final dishes = await recipes.dishes(query: _query);
        if (generation != _generation) return;
        _dishes = dishes;
      }
    } catch (_) {
      if (generation == _generation) _failed = true;
    } finally {
      if (generation == _generation && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final recipes = context.watch<RecipesController>();
    final inFamily = context.watch<FamilyController?>()?.inFamily ?? false;
    // Leaving the family while on its shelf: back to Mine.
    final shelf = !inFamily && _shelf == RecipeShelf.family ? RecipeShelf.mine : _shelf;
    bool matches(String name) => _query.isEmpty || name.toLowerCase().contains(_query.toLowerCase());

    final List<Widget> rows;
    String? empty;
    switch (shelf) {
      case RecipeShelf.mine || RecipeShelf.family:
        final list = (shelf == RecipeShelf.mine ? recipes.recipes : recipes.familyRecipes).where((r) => matches(r.name)).toList();
        rows = [for (final r in list) RecipeRow(recipe: r)];
        if (list.isEmpty && recipes.loaded) empty = shelf == RecipeShelf.mine ? l.recipesEmptyMine : l.recipesEmptyFamily;
      case RecipeShelf.community:
        rows = [
          for (final r in _community) RecipeRow(recipe: r),
          if (_next != null && !_loading)
            NotebookRow(
              onTap: () => _fetch(more: true),
              child: Text(l.recipesLoadMore, style: TextStyle(color: nb.pandanDeep, fontWeight: FontWeight.w600)),
            ),
        ];
        if (_community.isEmpty && !_loading) empty = l.recipesEmptyCommunity;
      case RecipeShelf.catalogue:
        rows = [for (final d in _dishes) _DishRow(dish: d)];
        if (_dishes.isEmpty && !_loading) empty = l.recipesEmptyCatalogue;
    }

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.recipesTitle)),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: () => shelf == RecipeShelf.mine || shelf == RecipeShelf.family ? recipes.load() : _fetch(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              NotebookRow(
                mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
                trailing: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _typed('');
                        },
                      ),
                child: TextField(
                  controller: _search,
                  onChanged: (t) {
                    setState(() {}); // the clear button
                    _typed(t);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: l.recipesSearchHint, border: InputBorder.none),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 4, 12, 4),
                child: NotebookSegmented<RecipeShelf>(
                    selected: shelf,
                    onChanged: _pick,
                    segments: [
                      NotebookSegment(value: RecipeShelf.mine, label: l.recipesMine),
                      if (inFamily) NotebookSegment(value: RecipeShelf.family, label: l.recipesFamily),
                      NotebookSegment(value: RecipeShelf.community, label: l.recipesCommunity),
                      NotebookSegment(value: RecipeShelf.catalogue, label: l.recipesCatalogue),
                    ],
                  ),
              ),
              if (_failed)
                NotebookRow(
                  mark: Icon(Icons.cloud_off, size: 20, color: nb.margin),
                  onTap: _fetch,
                  child: Text(l.recipesLoadFailed2),
                ),
              ...rows,
              if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator.adaptive())),
              if (empty != null && !_failed) NotebookRow(minHeight: 96, child: Text(empty, style: TextStyle(color: nb.inkSoft))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A recipe on its line: the name, then whose it is (someone else's) and its size.
class RecipeRow extends StatelessWidget {
  const RecipeRow({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final owner = recipe.owner;
    final details = [
      if (owner != null && !owner.isMe && owner.name != null) l.recipeBy(owner.name!),
      if (recipe.ingredientCount > 0) l.recipeIngredientCount(recipe.ingredientCount),
    ];
    return NotebookRow(
      mark: Icon(_visibilityIcon(recipe.visibility, mine: owner?.isMe ?? true), size: 20, color: nb.inkSoft),
      trailing: switch (recipe.shareId) {
        final id? => SharePhoto(id),
        null => null,
      },
      onTap: () => context.push('/recipes/${recipe.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (details.isNotEmpty)
            Text(details.join(' · '), style: text.bodyMedium?.copyWith(color: nb.inkSoft)),
        ],
      ),
    );
  }
}

/// The book icon for your own, people for a family member's, a globe for a public one.
IconData _visibilityIcon(RecipeVisibility v, {required bool mine}) => switch (v) {
  RecipeVisibility.public => Icons.public,
  RecipeVisibility.family => mine ? Icons.menu_book : Icons.people_outline,
  RecipeVisibility.private => Icons.menu_book,
};

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return NotebookRow(
      mark: Icon(Icons.restaurant_menu, size: 20, color: nb.inkSoft),
      onTap: () => context.push('/recipes/${dish.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dish.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            [?dish.category, if (dish.ingredientCount > 0) l.recipeIngredientCount(dish.ingredientCount)].join(' · '),
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}
