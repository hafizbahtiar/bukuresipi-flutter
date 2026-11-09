import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/recipe.dart';
import '../../../shares/presentation/widgets/share_image.dart';

/// A recipe on its line (Book, Home feed) and a catalogue dish on its line (Home feed).
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
      if (owner != null && !owner.isMe && owner.name != null)
        l.recipeBy(owner.name!),
      if (recipe.ingredientCount > 0)
        l.recipeIngredientCount(recipe.ingredientCount),
    ];
    return NotebookRow(
      mark: Icon(
        _visibilityIcon(recipe.visibility, mine: owner?.isMe ?? true),
        size: 20,
        color: nb.inkSoft,
      ),
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
          if (details.isNotEmpty)
            Text(
              details.join(' · '),
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
        ],
      ),
    );
  }
}

/// The book icon for your own, people for a family member's, a globe for a public one.
IconData _visibilityIcon(RecipeVisibility v, {required bool mine}) =>
    switch (v) {
      RecipeVisibility.public => Icons.public,
      RecipeVisibility.family => mine ? Icons.menu_book : Icons.people_outline,
      RecipeVisibility.private => Icons.menu_book,
    };

class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.dish});

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
          Text(
            dish.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              ?dish.category,
              if (dish.ingredientCount > 0)
                l.recipeIngredientCount(dish.ingredientCount),
            ].join(' · '),
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}
