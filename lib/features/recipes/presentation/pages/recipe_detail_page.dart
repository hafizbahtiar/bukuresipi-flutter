import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_app_bar.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/pill_switch.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../owner/domain/owner_repository.dart';
import '../../../family/presentation/ask.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/recipe.dart';
import '../../../shopping/presentation/shopping_controller.dart';
import '../recipes_controller.dart';
import '../widgets/ingredient_picker.dart';
import '../widgets/recipe_variants.dart';
import 'recipe_edit_page.dart';

/// One imported recipe as a notebook page: what the post said, with the pieces it did not give marked.
/// What a card already knows of a recipe, handed to its page (go_router `extra`): the page opens with its photo
/// header at once, so the card's photo can fly into it (hero) instead of the page flip.
class RecipePreview {
  const RecipePreview({required this.name, this.cover, this.shareId});

  final String name;
  final String? cover;
  final String? shareId;

  bool get hasPhoto => cover != null || shareId != null;
}

/// The hero tag shared by a recipe's card photo and its page header.
Object recipePhotoTag(String recipeId) => 'recipe-photo-$recipeId';

/// The photo filling a card or the page header: the recipe's cover, else its share's picture; null = none.
Widget? recipePhoto(
  String recipeId, {
  String? cover,
  String? shareId,
  required Widget fallback,
  int cacheWidth = 600,
}) => switch ((cover, shareId)) {
  (final c?, _) => ShareFill(
    id: c,
    recipeId: recipeId,
    fallback: fallback,
    cacheWidth: cacheWidth,
  ),
  (null, final s?) => ShareFill(
    id: s,
    fallback: fallback,
    cacheWidth: cacheWidth,
  ),
  _ => null,
};

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.id, this.preview});

  final String id;
  final RecipePreview? preview;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  RecipeDetail? _recipe;
  Object? _error;
  bool _loading = true;

  /// The tab under the title: false = ingredients (and allergens), true = steps (and variants).
  bool _steps = false;
  late final _pages = PageController(initialPage: _steps ? 1 : 0);

  /// How far the page has been pulled down past its top in this drag; [_closeAt] closes it.
  double _pull = 0;
  bool _closing = false;
  static const _closeAt = 110.0;

  /// With a photo on top: pulling the page down past its top closes it, and the photo flies back to its card.
  /// Platform physics stay: Android's clamping scroll reports the pull as overscroll, iOS's bounce as a negative
  /// offset.
  Widget _pullToClose(bool on, Widget child) => !on
      ? child
      : NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis != Axis.vertical || _closing) return false;
            final dragging = switch (n) {
              ScrollUpdateNotification(:final dragDetails) =>
                dragDetails != null,
              OverscrollNotification(:final dragDetails) => dragDetails != null,
              _ => false,
            };
            var pull = _pull;
            if (n is ScrollStartNotification || n is ScrollEndNotification) {
              pull = 0;
            } else if (dragging &&
                n is OverscrollNotification &&
                n.overscroll < 0) {
              pull -= n.overscroll;
            } else if (dragging &&
                n.metrics.pixels < n.metrics.minScrollExtent) {
              pull = n.metrics.minScrollExtent - n.metrics.pixels;
            } else if (dragging) {
              pull = 0; // scrolled back into the page
            }
            if (pull >= _closeAt) {
              _closing = true;
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop().then((closed) {
                // Nothing to go back to (the first page): the page settles again.
                if (!closed && mounted) {
                  setState(() {
                    _closing = false;
                    _pull = 0;
                  });
                }
              });
            }
            if (pull != _pull) setState(() => _pull = pull);
            return false;
          },
          // Follows the finger a little: the page shrinks toward its card as it is pulled.
          child: Transform.scale(
            scale: 1 - 0.06 * (_pull / _closeAt).clamp(0.0, 1.0),
            child: child,
          ),
        );

  /// The page's NestedScrollView, for its outer scroll (how far the photo bar has collapsed).
  final _nested = GlobalKey<NestedScrollViewState>();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recipe = await context.read<RecipesController>().detail(widget.id);
      if (mounted) {
        setState(() {
          _recipe = recipe;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  // Called after awaits: the page may be gone by then.
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _remove(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final recipes = context.read<RecipesController>();
    if (!await showNotebookDialog(
      context,
      message: recipe.sourceType == RecipeSourceType.catalogue
          ? l.dishRemoveConfirm
          : l.recipeRemoveConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.remove,
    )) {
      return;
    }
    try {
      await recipes.remove(recipe.id);
      await navigator.maybePop();
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _addToList(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final shopping = context.read<ShoppingController>();
    final inFamily = context.read<FamilyController?>()?.inFamily ?? false;
    // In a family: which list, asked the first time, then remembered.
    var family = false;
    if (inFamily) {
      final picked =
          shopping.lastRecipeList ??
          await showNotebookSheet<bool>(
            context,
            builder: (sheet) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                NotebookRow(
                  child: Text(
                    l.shoppingWhichList,
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
                NotebookRow(
                  onTap: () => Navigator.of(sheet).pop(false),
                  child: Text(l.shoppingMine),
                ),
                NotebookRow(
                  onTap: () => Navigator.of(sheet).pop(true),
                  child: Text(l.shoppingFamily),
                ),
              ],
            ),
          );
      if (picked == null) return;
      family = picked;
    }
    try {
      final added = await shopping.addRecipe(recipe.id, family: family);
      _snack(added == 0 ? l.shoppingAlreadyAdded : l.shoppingAdded(added));
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _copy(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    try {
      final copy = await context.read<RecipesController>().copy(recipe.id);
      _snack(l.recipeCopied);
      router.replace('/recipes/${copy.id}');
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  /// The owner's choice, each with who will see it. Public asks for a name first when there is none.
  Future<void> _visibility(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final recipes = context.read<RecipesController>();
    final inFamily = context.read<FamilyController?>()?.inFamily ?? false;
    final picked = await showNotebookSheet<RecipeVisibility>(
      context,
      builder: (sheet) {
        final nb = Notebook.of(sheet);
        final text = Theme.of(sheet).textTheme;
        Widget choice(RecipeVisibility v, String label, String hint) =>
            NotebookRow(
              mark: Icon(
                visibilityIcon(v),
                size: 20,
                color: v == recipe.visibility ? nb.pandan : nb.inkSoft,
              ),
              trailing: v == recipe.visibility
                  ? Icon(Icons.check, color: nb.pandan)
                  : null,
              onTap: () => Navigator.of(sheet).pop(v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(
                    hint,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            NotebookRow(child: Text(l.visTitle, style: text.titleMedium)),
            choice(RecipeVisibility.private, l.visPrivate, l.visPrivateHint),
            if (inFamily || recipe.visibility == RecipeVisibility.family)
              choice(RecipeVisibility.family, l.visFamily, l.visFamilyHint),
            choice(RecipeVisibility.public, l.visPublic, l.visPublicHint),
          ],
        );
      },
    );
    if (picked == null || picked == recipe.visibility || !mounted) return;
    try {
      await withName(context, () async {
        final saved = await recipes.setVisibility(recipe.id, picked);
        if (mounted) setState(() => _recipe = saved);
      });
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _report(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final recipes = context.read<RecipesController>();
    final reason = await showNotebookSheet<String>(
      context,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          NotebookRow(
            child: Text(
              l.recipeReportTitle,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final (code, label) in [
            ('copyright', l.reasonCopyright),
            ('spam', l.reasonSpam),
            ('offensive', l.reasonOffensive),
            ('wrong_info', l.reasonWrongInfo),
            ('other', l.reasonOther),
          ])
            NotebookRow(
              onTap: () => Navigator.of(sheet).pop(code),
              child: Text(label),
            ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await recipes.report(recipe.id, reason);
      _snack(l.recipeReported);
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  /// Owner: take someone's public recipe off Community without waiting for a report. Reloads to show it hidden.
  Future<void> _hide(RecipeDetail recipe) async {
    final l = AppLocalizations.of(context);
    final owner = context.read<OwnerRepository>();
    final sure = await showNotebookDialog(
      context,
      message: l.recipeHideConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.recipeHide,
    );
    if (!sure) return;
    try {
      await owner.hideRecipe(recipe.id);
      await _load();
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _edit(RecipeDetail recipe) async {
    final saved = await Navigator.of(context).push<RecipeDetail>(
      MaterialPageRoute(builder: (_) => RecipeEditPage(recipe: recipe)),
    );
    if (saved != null && mounted) setState(() => _recipe = saved);
  }

  Future<void> _pick(RecipeDetail recipe, int index) async {
    final l = AppLocalizations.of(context);
    final recipes = context.read<RecipesController>();
    final line = recipe.ingredients[index];
    final picked = await pickIngredient(
      context,
      line: line.rawText ?? line.label,
      linked: line.name != null,
    );
    if (picked == null) return;
    try {
      final updated = await recipes.linkIngredient(
        recipe.id,
        index,
        picked.name,
      );
      if (mounted) setState(() => _recipe = updated);
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final recipe = _recipe;
    // The header photo: a screen wide, so decoded larger than a card's.
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(600, 1600);
    Widget fallback() => ColoredBox(color: Notebook.of(context).mist);
    if (_loading) {
      final p = widget.preview;
      // From a card with a photo: the header is there at once, for the photo to fly into.
      if (p != null && p.hasPhoto) {
        return Scaffold(
          body: _pullToClose(
            true,
            CustomScrollView(
              slivers: [
                CoverAppBar(
                  photo: recipePhoto(
                    widget.id,
                    cover: p.cover,
                    shareId: p.shareId,
                    fallback: fallback(),
                    cacheWidth: cacheWidth,
                  )!,
                  title: p.name,
                  heroTag: recipePhotoTag(widget.id),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (recipe == null) {
      final gone =
          _error is ApiException && (_error as ApiException).status == 404;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              gone ? l.recipeGone : errorText(l, _error ?? 'unknown'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final source = recipe.sourceUrl;
    // Catalogue dishes credit the recipe they were built from; their steps stay there (not copied).
    final catalogue = recipe.sourceType == RecipeSourceType.catalogue;
    // Tabs only when there are two sections to switch between (a catalogue dish: the original's link, then variants).
    final tabs =
        recipe.ingredients.isNotEmpty &&
        (recipe.steps.isNotEmpty || (catalogue && source != null));
    // A photo opens the page as its top bar (CoverAppBar); none = a plain bar, the title starts the page.
    final photo = recipePhoto(
      recipe.id,
      cover: recipe.cover,
      shareId: recipe.shareId,
      fallback: fallback(),
      cacheWidth: cacheWidth,
    );
    final coverBar = photo == null
        ? null
        : CoverAppBar(
            photo: photo,
            title: recipe.name,
            heroTag: recipePhotoTag(recipe.id),
          );
    final header = SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 12, 20, 0),
          child: Text(
            recipe.name,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
        if (_byLine(l, recipe) case final by?)
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 4, 20, 0),
            child: Text(
              by,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          ),
        if (recipe.canEdit && recipe.cover == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 6, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: const ValueKey('recipe-add-cover'),
                avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(l.recipeCoverAdd),
                onPressed: () => _edit(recipe),
              ),
            ),
          ),
        if (recipe.canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 6, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(visibilityIcon(recipe.visibility), size: 18),
                label: Text(switch (recipe.visibility) {
                  RecipeVisibility.private => l.visPrivate,
                  RecipeVisibility.family => l.visFamily,
                  RecipeVisibility.public => l.visPublic,
                }),
                tooltip: l.visTitle,
                onPressed: () => _visibility(recipe),
              ),
            ),
          ),
        if (recipe.hidden)
          NotebookRow(
            mark: Icon(
              Icons.visibility_off_outlined,
              size: 18,
              color: nb.margin,
            ),
            child: Text(
              l.recipeHidden,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          ),
        if (recipe.missing.isNotEmpty)
          NotebookRow(
            mark: Icon(Icons.info_outline, size: 18, color: nb.margin),
            child: Text(
              _missingText(l, recipe.missing),
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          ),
      ],
    );
    final bar = SliverPersistentHeader(
      pinned: true,
      delegate: NotebookPinnedBar(
        height: MediaQuery.textScalerOf(context).scale(40) + 16,
        child: PillSwitch(
          expand: true,
          value: _steps,
          onChanged: (v) => setState(() => _steps = v),
          pages: _pages,
          options: [
            (
              false,
              Text(
                l.recipeIngredients,
                key: const ValueKey('recipe-tab-ingredients'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              null,
            ),
            (
              true,
              Text(
                l.recipeSteps,
                key: const ValueKey('recipe-tab-steps'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              null,
            ),
          ],
        ),
      ),
    );
    Widget list(List<Widget> rows) => SliverPadding(
      padding: const EdgeInsets.only(bottom: ActionDock.clearance),
      sliver: SliverList.list(children: rows),
    );
    final ingredientRows = <Widget>[
      // No heading over an empty section, nor over a tab's own section.
      if (recipe.ingredients.isNotEmpty && !tabs)
        NotebookHeading(l.recipeIngredients),
      for (final (index, i) in recipe.ingredients.indexed)
        NotebookRow(
          // Tap: link the line to a catalogue ingredient (allergens, shopping hints) or change that link.
          onTap: recipe.canEdit ? () => _pick(recipe, index) : null,
          trailing: i.name == null
              ? Tooltip(
                  message: l.ingredientUnrecognised,
                  child: Icon(Icons.help_outline, size: 18, color: nb.inkSoft),
                )
              : null,
          mark: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nb.inkSoft,
            ),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                if (i.amount case final amount?)
                  TextSpan(
                    text: '$amount  ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                TextSpan(text: i.label),
              ],
            ),
          ),
        ),
      // Only when something was found: no section must never read as "safe".
      if (recipe.allergens.isNotEmpty) ...[
        NotebookHeading(l.recipeAllergens),
        for (final a in recipe.allergens)
          NotebookRow(
            mark: Icon(Icons.warning_amber_rounded, size: 18, color: nb.margin),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: a.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' · ${a.ingredients.join(', ')}'),
                ],
              ),
            ),
          ),
        NotebookRow(
          child: Text(
            [
              l.recipeAllergenNote,
              if (recipe.uncheckedIngredients > 0)
                l.recipeAllergenUnchecked(recipe.uncheckedIngredients),
            ].join(' '),
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ),
      ],
    ];
    final stepRows = <Widget>[
      if ((recipe.steps.isNotEmpty || (catalogue && source != null)) && !tabs)
        NotebookHeading(l.recipeSteps),
      if (catalogue && recipe.steps.isEmpty && source != null)
        NotebookRow(
          mark: Icon(Icons.menu_book_outlined, size: 20, color: nb.pandanDeep),
          onTap: () => openLink(context, source, failed: l.openFailed),
          trailing: Icon(Icons.open_in_new, size: 18, color: nb.pandanDeep),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.recipeStepsAtOriginal,
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                Uri.tryParse(source)?.host ?? source,
                style: text.bodyMedium?.copyWith(color: nb.pandanDeep),
              ),
            ],
          ),
        ),
      for (final s in recipe.steps)
        NotebookRow(
          mark: Text(
            '${s.stepNo}',
            style: nb.hand.copyWith(fontSize: 22, color: nb.inkSoft),
          ),
          child: Text(s.instruction),
        ),
      if (catalogue)
        RecipeVariants(
          recipeId: recipe.id,
          owner: context.read<AuthController?>()?.user?.isOwner ?? false,
        ),
    ];
    return Scaffold(
      appBar: coverBar == null ? AppBar() : null,
      extendBody: true,
      bottomNavigationBar: ActionDock(
        actions: [
          if (source case final url?)
            DockAction(
              icon: Icons.open_in_new,
              label: catalogue ? l.recipeOpenOriginal : l.recipeOpenSource,
              onPressed: () => openLink(context, url, failed: l.openFailed),
            ),
          if (recipe.ingredients.isNotEmpty)
            DockAction(
              icon: Icons.add_shopping_cart,
              label: l.shoppingAddRecipe,
              onPressed: () => _addToList(recipe),
            ),
          // Only the owner edits or removes; anyone else may make their own copy (or report a public one).
          if (recipe.canEdit) ...[
            DockAction(
              icon: Icons.edit_outlined,
              label: l.recipeEdit,
              onPressed: () => _edit(recipe),
            ),
            DockAction(
              icon: Icons.delete_outline,
              label: l.remove,
              tooltip: l.recipeRemove,
              danger: true,
              onPressed: () => _remove(recipe),
            ),
          ] else ...[
            // The app's owner keeps the catalogue: edit (with the AI draft) or delete it for everyone.
            if (recipe.sourceType == RecipeSourceType.catalogue &&
                (context.read<AuthController?>()?.user?.isOwner ?? false)) ...[
              DockAction(
                icon: Icons.edit_outlined,
                label: l.recipeEdit,
                onPressed: () => _edit(recipe),
              ),
              DockAction(
                icon: Icons.delete_outline,
                label: l.remove,
                tooltip: l.recipeRemove,
                danger: true,
                onPressed: () => _remove(recipe),
              ),
            ],
            DockAction(
              icon: Icons.copy_outlined,
              label: l.recipeCopy,
              onPressed: () => _copy(recipe),
            ),
            if (recipe.visibility == RecipeVisibility.public &&
                recipe.owner != null)
              // The owner removes it from Community directly; anyone else reports it to the owner.
              (context.read<AuthController?>()?.user?.isOwner ?? false)
                  ? DockAction(
                      icon: Icons.visibility_off_outlined,
                      label: l.recipeHide,
                      danger: true,
                      onPressed: recipe.hidden ? null : () => _hide(recipe),
                    )
                  : DockAction(
                      icon: Icons.flag_outlined,
                      label: l.report,
                      onPressed: () => _report(recipe),
                    ),
          ],
        ],
      ),
      body: _pullToClose(
        coverBar != null,
        NotebookPage(
          child: tabs
              ? NestedScrollView(
                  key: _nested,
                  headerSliverBuilder: (context, _) => [
                    // Pinned on its own: it stays as a bar (back button) once the photo has scrolled away.
                    ?coverBar,
                    header,
                    // The pinned pill (and the photo bar, pinned too): absorbed so each tab's list starts below them
                    // (SliverOverlapInjector).
                    SliverOverlapAbsorber(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context,
                      ),
                      sliver: bar,
                    ),
                  ],
                  // One page per tab: swiped, or driven by the pill (it follows the swipe).
                  body: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _steps = i == 1),
                    children: [
                      for (final (i, rows) in [
                        ingredientRows,
                        stepRows,
                      ].indexed)
                        Builder(
                          builder: (context) => CustomScrollView(
                            key: PageStorageKey('recipe-tab-$i'),
                            slivers: [
                              if (coverBar != null)
                                SliverToBoxAdapter(
                                  child: _UnderBar(
                                    nested: _nested,
                                    bar:
                                        kToolbarHeight +
                                        MediaQuery.paddingOf(context).top,
                                  ),
                                ),
                              SliverOverlapInjector(
                                handle:
                                    NestedScrollView.sliverOverlapAbsorberHandleFor(
                                      context,
                                    ),
                              ),
                              list(rows),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    ?coverBar,
                    header,
                    list([...ingredientRows, ...stepRows]),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The lock, people or globe of a visibility (recipe chip and sheet).
IconData visibilityIcon(RecipeVisibility v) => switch (v) {
  RecipeVisibility.private => Icons.lock_outline,
  RecipeVisibility.family => Icons.people_outline,
  RecipeVisibility.public => Icons.public,
};

/// Who it is by and where it came from, for a recipe that is not the caller's (a shared one always shows credit).
String? _byLine(AppLocalizations l, RecipeDetail r) {
  if (r.sourceType == RecipeSourceType.catalogue) {
    final host = Uri.tryParse(r.sourceUrl ?? '')?.host;
    return host == null || host.isEmpty
        ? l.recipeCatalogue
        : l.recipeCatalogueFrom(host);
  }
  if (r.canEdit) return null;
  return [
    if (r.owner?.name case final name?) l.recipeBy(name),
    switch (r.sourceType) {
      RecipeSourceType.link => r.platform ?? r.sourceUrl ?? '',
      RecipeSourceType.screenshot => l.recipeFromScreenshot,
      _ => l.recipeTyped,
    },
  ].where((s) => s.isNotEmpty).join(' · ');
}

String _missingText(AppLocalizations l, List<String> missing) {
  final parts = [
    if (missing.contains('name')) l.recipeMissingName,
    if (missing.contains('ingredients')) l.recipeMissingIngredients,
    if (missing.contains('steps')) l.recipeMissingSteps,
  ];
  return '${l.recipeIncomplete}: ${parts.join(', ')}';
}

/// Room at the top of a tab's list for the pinned photo bar, which covers the list's start only as it finishes
/// collapsing: 0 while the photo is open, growing to the bar's height ([bar]) over the outer scroll's last [bar]
/// pixels. (The pill has NestedScrollView's absorber; a second fixed one would leave a gap while the photo is open.)
class _UnderBar extends StatelessWidget {
  const _UnderBar({required this.nested, required this.bar});

  final GlobalKey<NestedScrollViewState> nested;
  final double bar;

  @override
  Widget build(BuildContext context) {
    final outer = nested.currentState?.outerController;
    if (outer == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: outer,
      builder: (context, _) {
        // Before the first layout the outer scroll has no size yet.
        if (!outer.hasClients || !outer.position.hasContentDimensions) {
          return const SizedBox.shrink();
        }
        final p = outer.position;
        return SizedBox(
          height: (p.pixels - (p.maxScrollExtent - bar)).clamp(0.0, bar),
        );
      },
    );
  }
}
