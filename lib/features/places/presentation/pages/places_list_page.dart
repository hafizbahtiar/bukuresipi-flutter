import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../recipes/domain/recipe.dart';
import '../../../recipes/presentation/recipes_controller.dart';
import '../../../shares/presentation/recent_shares.dart';
import '../../../shares/presentation/widgets/share_reading.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/merge_sheet.dart';
import '../../../shares/presentation/widgets/share_image.dart';

enum BookFilter { all, mine, family }

/// The Book tab: a notebook page, one saved place per line, newest first. In a family it also holds the members'
/// places (All · Mine · Family); the search box filters places and recipes by name on the phone (the book is small).
class PlacesListPage extends StatefulWidget {
  const PlacesListPage({super.key});

  @override
  State<PlacesListPage> createState() => _PlacesListPageState();
}

class _PlacesListPageState extends State<PlacesListPage> {
  final _search = TextEditingController();
  BookFilter _filter = BookFilter.all;

  /// Owner's Merge: the restaurants picked (null = not merging). Recipes can't be picked.
  Set<String>? _merging;

  /// The merge request is running: the button shows a spinner and can't be tapped again.
  bool _mergeBusy = false;

  Future<void> _merge(List<Place> picked) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    final r = await showNotebookSheet<({String into, String? name})>(
      context,
      builder: (_) => MergeSheet(places: picked),
    );
    if (r == null || !mounted) return;
    setState(() => _mergeBusy = true);
    try {
      await places.mergeRestaurants(
        [
          for (final p in picked)
            if (p.restaurant.id != r.into) p.restaurant.id,
        ],
        r.into,
        name: r.name,
      );
      if (mounted) setState(() => _merging = null);
      messenger.showSnackBar(SnackBar(content: Text(l.mergeDone)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _mergeBusy = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final places = context.watch<PlacesController>();
    final recipes = context.watch<RecipesController>();
    final inFamily = context.watch<FamilyController?>()?.inFamily ?? false;
    final filter = inFamily ? _filter : BookFilter.all;
    final q = _search.text.trim().toLowerCase();
    bool hit(String? s) => q.isEmpty || (s?.toLowerCase().contains(q) ?? false);
    final searching = q.isNotEmpty || filter != BookFilter.all;
    final merging = _merging;
    final isOwner = context.watch<AuthController?>()?.user?.isOwner ?? false;
    final list = [
      for (final p in places.places)
        if ((hit(p.restaurant.name) ||
                hit(p.savedBranch?.where) ||
                hit(p.note)) &&
            switch (filter) {
              BookFilter.all => true,
              BookFilter.mine => p.mine,
              BookFilter.family => p.savedByOthers.isNotEmpty,
            })
          p,
    ];
    final bookRecipes = [
      for (final r
          in filter == BookFilter.family
              ? recipes.familyRecipes
              : recipes.recipes)
        if (hit(r.name)) r,
    ];
    final tools = [
      NotebookRow(
        mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
        trailing: q.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(_search.clear),
              ),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.bookSearchHint,
            border: InputBorder.none,
          ),
        ),
      ),
      if (inFamily)
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 4, 12, 4),
          child: NotebookSegmented<BookFilter>(
            selected: filter,
            onChanged: (f) => setState(() => _filter = f),
            segments: [
              NotebookSegment(value: BookFilter.all, label: l.bookAll),
              NotebookSegment(value: BookFilter.mine, label: l.bookMine),
              NotebookSegment(value: BookFilter.family, label: l.bookFamily),
            ],
          ),
        ),
    ];
    final shared = context.watch<RecentShares>();
    // Shares the server is still reading, or could not read (last 24 h), above the saved places.
    final inbox = [
      if (merging == null)
        for (final s in shared.reading)
          ReadingShareRow(key: ValueKey('reading-${s.id}'), share: s),
      if (merging == null)
        for (final s in shared.failed)
          ShareProblemRow(key: ValueKey('problem-${s.id}'), share: s),
    ];

    final List<Widget> lines;
    if (!places.loaded || !recipes.loaded) {
      lines = const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    } else if (searching && list.isEmpty && bookRecipes.isEmpty) {
      lines = [_Note(text: l.bookNoMatch)];
    } else if (list.isEmpty && places.error != null) {
      lines = [
        _Note(text: l.placesLoadFailed),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: notebookGutter + 2),
            child: TextButton(onPressed: places.load, child: Text(l.tryAgain)),
          ),
        ),
        if (recipes.error != null) _RecipesError(onRetry: recipes.load),
        for (final r in bookRecipes) RecipeTile(recipe: r),
      ];
    } else if (list.isEmpty && bookRecipes.isEmpty && recipes.error != null) {
      lines = [_RecipesError(onRetry: recipes.load)];
    } else if (list.isEmpty && bookRecipes.isEmpty && inbox.isEmpty) {
      lines = [_Note(text: l.homeEmpty)];
    } else {
      // One list, newest first: a shop icon = a place, a book icon = a recipe.
      final items = <(DateTime, Widget)>[
        for (final p in list)
          (
            p.createdAt,
            FreshHighlight(
              key: ValueKey('place-${p.id}'),
              fresh: shared.isFresh(p.restaurant.id),
              child: merging == null
                  ? PlaceTile(place: p)
                  : _Pickable(
                      key: ValueKey('merge-${p.restaurant.id}'),
                      picked: merging.contains(p.restaurant.id),
                      onTap: () => setState(() {
                        if (!merging.remove(p.restaurant.id)) {
                          merging.add(p.restaurant.id);
                        }
                      }),
                      child: PlaceTile(place: p),
                    ),
            ),
          ),
        for (final r in bookRecipes)
          (
            r.createdAt,
            FreshHighlight(
              key: ValueKey('recipe-${r.id}'),
              fresh: shared.isFresh(r.id),
              // Merging is for places: a recipe stays greyed out and can't be picked.
              child: merging == null
                  ? RecipeTile(recipe: r)
                  : IgnorePointer(
                      child: Opacity(
                        opacity: 0.35,
                        child: RecipeTile(recipe: r),
                      ),
                    ),
            ),
          ),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      lines = [
        if (recipes.error != null) _RecipesError(onRetry: recipes.load),
        for (final i in items) i.$2,
      ];
    }

    final picked = [
      if (merging != null)
        for (final p in places.places)
          if (merging.contains(p.restaurant.id)) p,
    ];
    return PopScope(
      // Back leaves merge mode first, not the page.
      canPop: merging == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_mergeBusy) setState(() => _merging = null);
      },
      child: Scaffold(
        appBar: merging != null
            ? AppBar(
                toolbarHeight: 76,
                leading: IconButton(
                  key: const ValueKey('merge-cancel'),
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  icon: const Icon(Icons.close),
                  onPressed: _mergeBusy
                      ? null
                      : () => setState(() => _merging = null),
                ),
                title: Text(l.mergePicked(picked.length)),
              )
            : AppBar(
                toolbarHeight: 76,
                title: NotebookTitle(l.homeTitle),
                actions: [
                  // Owner: one company saved under several names becomes one restaurant.
                  if (isOwner)
                    IconButton(
                      key: const ValueKey('book-merge'),
                      tooltip: l.mergeAction,
                      icon: const Icon(Icons.merge_type),
                      onPressed: () => setState(() => _merging = {}),
                    ),
                  IconButton(
                    key: const ValueKey('book-map'),
                    tooltip: l.navMap,
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => context.push('/map'),
                  ),
                ],
              ),
        // Merge mode: the button at the bottom, where the thumb is, with what to do next.
        bottomNavigationBar: merging == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (picked.length < 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l.mergeNeedTwo,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('merge-next'),
                          icon: _mergeBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.merge_type),
                          onPressed: picked.length < 2 || _mergeBusy
                              ? null
                              : () => _merge(picked),
                          label: Text(
                            picked.length < 2
                                ? l.mergeAction
                                : '${l.mergeAction} (${picked.length})',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        body: NotebookPage(
          child: RefreshIndicator(
            // Everything on the page: a new recipe or a cleared share shows without a restart.
            onRefresh: () =>
                Future.wait([places.load(), recipes.load(), shared.load()]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: navRoom(context)),
              // The search box once there is something to search.
              children: [
                ...inbox,
                if (places.places.isNotEmpty ||
                    recipes.recipes.isNotEmpty ||
                    searching)
                  ...tools,
                ...lines,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One saved place on its line: a mark in the margin (pinned or not), the name, then where it is.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final branch = place.savedBranch;
    final pinned = place.pins.isNotEmpty;
    final where = pinned ? (branch?.where ?? branch?.label) : l.noPin;
    final others = place.savedByOthers;
    return NotebookRow(
      trailing: place.private || place.shareId != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (place.private)
                  Tooltip(
                    message: l.placeOnlyMe,
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: nb.inkSoft,
                    ),
                  ),
                if (place.shareId case final id?) SharePhoto(id),
              ],
            )
          : null,
      // Green = on the map, yellow = no pin yet (as PinMark).
      mark: Icon(
        Icons.storefront,
        size: 20,
        color: pinned ? nb.pandan : nb.kunyit,
      ),
      onTap: () => context.push('/places/${place.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.restaurant.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (where != null && where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
          if (others.isNotEmpty)
            Text(
              others.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: nb.pandanDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class RecipeTile extends StatelessWidget {
  const RecipeTile({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final counts = [
      if (recipe.ingredientCount > 0)
        l.recipeIngredientCount(recipe.ingredientCount),
      if (recipe.stepCount > 0) l.recipeStepCount(recipe.stepCount),
    ];
    return NotebookRow(
      mark: Icon(Icons.menu_book, size: 20, color: nb.inkSoft),
      trailing: switch ((recipe.cover, recipe.shareId)) {
        (final cover?, _) => SharePhoto.cover(recipe.id, cover),
        (null, final id?) => SharePhoto(id, drawing: true),
        _ => const SharePhoto.placeholder(),
      },
      onTap: () => context.push('/recipes/${recipe.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                counts.join(' · '),
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

/// A recipe reload that failed while the rest of the book still shows: the message and a retry.
class _RecipesError extends StatelessWidget {
  const _RecipesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return NotebookRow(
      mark: Icon(Icons.error_outline, size: 18, color: nb.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.recipesLoadFailed),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.tryAgain),
          ),
        ],
      ),
    );
  }
}

/// A line of guidance written on the page.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 24, 24, 8),
    child: Text(
      text,
      style: Notebook.of(context).hand.copyWith(fontSize: 24, height: 1.25),
    ),
  );
}

/// A place in Merge mode: a tap picks it (tick on the right); its own taps are off.
class _Pickable extends StatelessWidget {
  const _Pickable({
    super.key,
    required this.picked,
    required this.onTap,
    required this.child,
  });

  final bool picked;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Semantics(
      selected: picked,
      button: true,
      child: Material(
        // A picked place stands out on the whole line, not only by its tick.
        color: picked ? nb.pandan.withValues(alpha: 0.10) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(child: IgnorePointer(child: child)),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  picked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: picked ? nb.pandan : nb.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
