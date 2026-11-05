import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../family/presentation/ask.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/recipe.dart';
import '../../../shopping/presentation/shopping_controller.dart';
import '../recipes_controller.dart';
import '../widgets/ingredient_picker.dart';
import 'recipe_edit_page.dart';

/// One imported recipe as a notebook page: what the post said, with the pieces it did not give marked.
class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.id});

  final String id;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  RecipeDetail? _recipe;
  Object? _error;
  bool _loading = true;

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
      message: l.recipeRemoveConfirm,
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
      final picked = shopping.lastRecipeList ?? await showNotebookSheet<bool>(
        context,
        builder: (sheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            NotebookRow(child: Text(l.shoppingWhichList, style: Theme.of(sheet).textTheme.titleMedium)),
            NotebookRow(onTap: () => Navigator.of(sheet).pop(false), child: Text(l.shoppingMine)),
            NotebookRow(onTap: () => Navigator.of(sheet).pop(true), child: Text(l.shoppingFamily)),
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
        Widget choice(RecipeVisibility v, String label, String hint) => NotebookRow(
          mark: Icon(visibilityIcon(v), size: 20, color: v == recipe.visibility ? nb.pandan : nb.inkSoft),
          trailing: v == recipe.visibility ? Icon(Icons.check, color: nb.pandan) : null,
          onTap: () => Navigator.of(sheet).pop(v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label), Text(hint, style: text.bodySmall?.copyWith(color: nb.inkSoft))],
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
          NotebookRow(child: Text(l.recipeReportTitle, style: Theme.of(sheet).textTheme.titleMedium)),
          for (final (code, label) in [
            ('copyright', l.reasonCopyright),
            ('spam', l.reasonSpam),
            ('offensive', l.reasonOffensive),
            ('wrong_info', l.reasonWrongInfo),
            ('other', l.reasonOther),
          ])
            NotebookRow(onTap: () => Navigator.of(sheet).pop(code), child: Text(label)),
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
    if (_loading) {
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
    return Scaffold(
      appBar: AppBar(),
      extendBody: true,
      bottomNavigationBar: ActionDock(
        actions: [
          if (source case final url?)
            DockAction(
              icon: Icons.open_in_new,
              label: l.recipeOpenSource,
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
            DockAction(
              icon: Icons.copy_outlined,
              label: l.recipeCopy,
              onPressed: () => _copy(recipe),
            ),
            if (recipe.visibility == RecipeVisibility.public && recipe.owner != null)
              DockAction(
                icon: Icons.flag_outlined,
                label: l.report,
                onPressed: () => _report(recipe),
              ),
          ],
        ],
      ),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: ActionDock.clearance),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 4, 20, 0),
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
                child: Text(by, style: text.bodyMedium?.copyWith(color: nb.inkSoft)),
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
                mark: Icon(Icons.visibility_off_outlined, size: 18, color: nb.margin),
                child: Text(l.recipeHidden, style: text.bodyMedium?.copyWith(color: nb.inkSoft)),
              ),
            if (recipe.shareId case final id?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  notebookGutter + 10,
                  0,
                  20,
                  0,
                ),
                child: ShareImage(id),
              ),
            if (recipe.missing.isNotEmpty)
              NotebookRow(
                mark: Icon(Icons.info_outline, size: 18, color: nb.margin),
                child: Text(
                  _missingText(l, recipe.missing),
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
              ),
            // No heading over an empty section: a post with no steps shows ingredients only.
            if (recipe.ingredients.isNotEmpty)
              NotebookHeading(l.recipeIngredients),
            for (final (index, i) in recipe.ingredients.indexed)
              NotebookRow(
                // Tap: link the line to a catalogue ingredient (allergens, shopping hints) or change that link.
                onTap: recipe.canEdit ? () => _pick(recipe, index) : null,
                trailing: i.name == null
                    ? Tooltip(
                        message: l.ingredientUnrecognised,
                        child: Icon(
                          Icons.help_outline,
                          size: 18,
                          color: nb.inkSoft,
                        ),
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
                  mark: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: nb.margin,
                  ),
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
            if (recipe.steps.isNotEmpty) NotebookHeading(l.recipeSteps),
            for (final s in recipe.steps)
              NotebookRow(
                mark: Text(
                  '${s.stepNo}',
                  style: nb.hand.copyWith(fontSize: 22, color: nb.inkSoft),
                ),
                child: Text(s.instruction),
              ),
          ],
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
  if (r.sourceType == RecipeSourceType.catalogue) return l.recipeCatalogue;
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
