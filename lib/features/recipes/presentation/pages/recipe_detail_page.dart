import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';

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

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
          DockAction(
            icon: Icons.delete_outline,
            label: l.remove,
            tooltip: l.recipeRemove,
            danger: true,
            onPressed: () => _remove(recipe),
          ),
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
            for (final i in recipe.ingredients)
              NotebookRow(
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

String _missingText(AppLocalizations l, List<String> missing) {
  final parts = [
    if (missing.contains('name')) l.recipeMissingName,
    if (missing.contains('ingredients')) l.recipeMissingIngredients,
    if (missing.contains('steps')) l.recipeMissingSteps,
  ];
  return '${l.recipeIncomplete}: ${parts.join(', ')}';
}
