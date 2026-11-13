import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/cover_app_bar.dart';
import '../../../../core/widgets/notebook_dialog.dart' show DialogTone;
import '../../../../core/widgets/skeleton.dart';
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

/// One imported recipe, standard (base) style: what the post said, with the pieces it did not give marked.
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

  @override
  void dispose() {
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
    if (!await showBaseDialog(
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
          await showBasePicker<bool>(
            context,
            title: l.shoppingWhichList,
            search: false,
            options: const [false, true],
            selected: null,
            label: (family) => family ? l.shoppingFamily : l.shoppingMine,
          );
      if (picked == null) return;
      family = picked;
    }
    // Optional lines: asked every time (it depends on what is being cooked). Closing the sheet adds nothing.
    final optional = recipe.ingredients.where((i) => i.optional).length;
    var skipOptional = false;
    if (optional > 0) {
      if (!mounted) return;
      final skip = await showBasePicker<bool>(
        context,
        title: l.shoppingOptionalTitle(optional),
        search: false,
        options: const [true, false],
        selected: null,
        label: (skip) => skip ? l.shoppingOptionalSkip : l.shoppingOptionalAll,
      );
      if (skip == null) return;
      skipOptional = skip;
    }
    try {
      final added = await shopping.addRecipe(
        recipe.id,
        family: family,
        skipOptional: skipOptional,
      );
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
    final picked = await showModalBottomSheet<RecipeVisibility>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        Widget choice(RecipeVisibility v, String label, String hint) =>
            ListTile(
              leading: Icon(visibilityIcon(v)),
              title: Text(label),
              subtitle: Text(hint),
              selected: v == recipe.visibility,
              trailing: v == recipe.visibility ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(sheet).pop(v),
            );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: spaceM),
          children: [
            ListTile(
              title: Text(
                l.visTitle,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
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
    final reasons = {
      'copyright': l.reasonCopyright,
      'spam': l.reasonSpam,
      'offensive': l.reasonOffensive,
      'wrong_info': l.reasonWrongInfo,
      'other': l.reasonOther,
    };
    final reason = await showBasePicker<String>(
      context,
      title: l.recipeReportTitle,
      search: false,
      options: reasons.keys.toList(),
      selected: null,
      label: (code) => reasons[code]!,
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
    final sure = await showBaseDialog(
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
      optional: line.optional,
    );
    if (picked == null) return;
    try {
      final updated = picked.optional != null
          ? await recipes.setIngredientOptional(
              recipe.id,
              index,
              picked.optional!,
            )
          : await recipes.linkIngredient(recipe.id, index, picked.name);
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
                const SliverToBoxAdapter(child: _Loading()),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: const SingleChildScrollView(child: _Loading()),
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
    final errorColor = Theme.of(context).colorScheme.error;
    final source = recipe.sourceUrl;
    // Catalogue dishes credit the recipe they were built from; their steps stay there (not copied).
    final catalogue = recipe.sourceType == RecipeSourceType.catalogue;
    final isOwner = context.read<AuthController?>()?.user?.isOwner ?? false;
    // A section shows only when it has something (a catalogue dish's steps: the original's link, then variants);
    // tabs only when there are two or more.
    final sections = [
      if (recipe.ingredients.isNotEmpty) _Section.ingredients,
      if (recipe.steps.isNotEmpty || (catalogue && source != null))
        _Section.steps,
      if (recipe.allergens.isNotEmpty) _Section.others,
    ];
    final tabs = sections.length > 1;
    // Only the owner edits or removes; anyone else may make their own copy (or report a public one). The app's
    // owner keeps the catalogue: edit (with the AI draft) or delete it for everyone.
    final manage = recipe.canEdit || (catalogue && isOwner);
    final hideOrReport =
        !recipe.canEdit &&
        recipe.visibility == RecipeVisibility.public &&
        recipe.owner != null;
    // Use first (cook, shop), then make it yours (copy, edit), then report; danger last, set apart by a line.
    final more = MoreMenu(
      actions: [
        if (recipe.ingredients.isNotEmpty)
          MenuAction(
            icon: Icons.add_shopping_cart,
            label: l.shoppingAddRecipe,
            onTap: () => _addToList(recipe),
          ),
        if (source case final url?)
          MenuAction(
            icon: Icons.open_in_new,
            label: catalogue ? l.recipeOpenOriginal : l.recipeOpenSource,
            onTap: () => openLink(context, url, failed: l.openFailed),
          ),
        if (!recipe.canEdit)
          MenuAction(
            icon: Icons.copy_outlined,
            label: l.recipeCopy,
            onTap: () => _copy(recipe),
          ),
        if (manage)
          MenuAction(
            icon: Icons.edit_outlined,
            label: l.recipeEdit,
            onTap: () => _edit(recipe),
          ),
        // Anyone else reports a public recipe to the owner; the owner hides it from Community directly.
        if (hideOrReport && !isOwner)
          MenuAction(
            icon: Icons.flag_outlined,
            label: l.report,
            onTap: () => _report(recipe),
          ),
        if (hideOrReport && isOwner)
          MenuAction(
            icon: Icons.visibility_off_outlined,
            label: l.recipeHide,
            danger: true,
            onTap: recipe.hidden ? null : () => _hide(recipe),
          ),
        if (manage)
          MenuAction(
            icon: Icons.delete_outline,
            label: recipe.canEdit ? l.recipeRemove : l.remove,
            danger: true,
            onTap: () => _remove(recipe),
          ),
      ],
    );
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
            actions: [more],
          );
    final header = SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
          child: Text(
            recipe.name,
            style: Notebook.of(context).hand
                .copyWith(fontSize: 34, height: 1.05),
          ),
        ),
        if (_byLine(l, recipe) case final by?)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceXs, spaceM, 0),
            child: Text(
              by,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          ),
        if (recipe.canEdit && recipe.cover == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
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
            padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
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
          ListTile(
            leading: Icon(Icons.visibility_off_outlined, color: errorColor),
            title: Text(l.recipeHidden),
          ),
        if (recipe.missing.isNotEmpty)
          ListTile(
            leading: Icon(Icons.info_outline, color: errorColor),
            title: Text(_missingText(l, recipe.missing)),
          ),
      ],
    );
    final ingredientRows = <Widget>[
      // No heading over an empty section, nor over a tab's own section.
      if (recipe.ingredients.isNotEmpty && !tabs)
        SectionHeader(l.recipeIngredients),
      for (final (index, i) in recipe.ingredients.indexed)
        ListTile(
          // Tap: link the line to a catalogue ingredient (allergens, shopping hints) or change that link.
          onTap: manage ? () => _pick(recipe, index) : null,
          trailing: i.name == null
              ? Tooltip(
                  message: l.ingredientUnrecognised,
                  // A phone has no hover: a tap explains the mark.
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.help_outline, size: 18, color: nb.inkSoft),
                )
              : null,
          minLeadingWidth: 0,
          leading: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nb.inkSoft,
            ),
          ),
          title: Text.rich(
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
          subtitle: i.optional
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TagChip(TileTag(l.recipeOptional)),
                  ),
                )
              : null,
        ),
    ];
    // Only when something was found: no section must never read as "safe".
    final otherRows = <Widget>[
      if (recipe.allergens.isNotEmpty) ...[
        SectionHeader(l.recipeAllergens),
        InfoCard(
          icon: Icons.health_and_safety_outlined,
          text: l.recipeAllergenInfo,
        ),
        for (final a in recipe.allergens)
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: errorColor),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: a.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' · ${a.ingredients.join(', ')}'),
                  if (a.optionalOnly)
                    TextSpan(text: ' (${l.recipeAllergenOptional})'),
                ],
              ),
            ),
          ),
        ListTile(
          title: Text(
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
      if (sections.contains(_Section.steps) && !tabs)
        SectionHeader(l.recipeSteps),
      if (catalogue && recipe.steps.isEmpty && source != null)
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          onTap: () => openLink(context, source, failed: l.openFailed),
          trailing: const Icon(Icons.open_in_new),
          title: Text(l.recipeStepsAtOriginal),
          subtitle: Text(Uri.tryParse(source)?.host ?? source),
        ),
      for (final s in recipe.steps)
        ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: nb.mist,
            foregroundColor: nb.pandanDeep,
            child: Text('${s.stepNo}', style: text.labelLarge),
          ),
          title: Text(s.instruction),
        ),
      if (catalogue) RecipeVariants(recipeId: recipe.id, owner: isOwner),
    ];
    return Scaffold(
      appBar: coverBar == null ? AppBar(actions: [more]) : null,
      body: _pullToClose(
        coverBar != null,
        DetailTabs(
          coverBar: coverBar,
          header: header,
          sections: [
            for (final section in sections)
              DetailSection(
                id: 'recipe-tab-${section.name}',
                label: switch (section) {
                  _Section.ingredients => l.recipeIngredients,
                  _Section.steps => l.recipeSteps,
                  _Section.others => l.recipeOthers,
                },
                rows: switch (section) {
                  _Section.ingredients => ingredientRows,
                  _Section.steps => stepRows,
                  _Section.others => otherRows,
                },
              ),
          ],
        ),
      ),
    );
  }
}

enum _Section { ingredients, steps, others }

/// The page's shape while it loads: title, by-line, tabs, then ingredient lines.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Padding(
      padding: const EdgeInsets.all(spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 240, height: 24),
          const SizedBox(height: spaceS),
          const SkeletonBox(width: 150),
          const SizedBox(height: spaceL),
          const SkeletonBox(height: 40, radius: 20),
          const SizedBox(height: spaceS),
          for (final w in const [0.7, 0.5, 0.8, 0.6, 0.4, 0.65])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: spaceM),
              child: Row(
                children: [
                  const SkeletonBox(width: 6, height: 6),
                  const SizedBox(width: spaceM),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: w,
                      child: const SkeletonBox(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
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
