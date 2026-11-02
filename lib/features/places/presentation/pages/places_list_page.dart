import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../recipes/presentation/recipes_controller.dart';
import '../../../shares/domain/share.dart';
import '../../../shares/presentation/recent_shares.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

/// The Book tab: a notebook page, one saved place per line, newest first.
class PlacesListPage extends StatelessWidget {
  const PlacesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final places = context.watch<PlacesController>();
    final list = places.places;
    final recipes = context.watch<RecipesController>();
    final shared = context.watch<RecentShares>();
    // Shares the server is still reading, or could not read (last 24 h), above the saved places.
    final inbox = [
      for (final _ in shared.reading)
        NotebookRow(
          mark: const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          child: Text(
            l.shareReadingLine,
            style: Notebook.of(context).hand.copyWith(fontSize: 22),
          ),
        ),
      for (final s in shared.failed)
        _FailedShare(key: ValueKey(s.id), share: s),
    ];

    final List<Widget> lines;
    if (!places.loaded || !recipes.loaded) {
      lines = const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
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
      ];
    } else if (list.isEmpty &&
        recipes.recipes.isEmpty &&
        recipes.error != null) {
      lines = [
        _Note(text: l.recipesLoadFailed),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: notebookGutter + 2),
            child: TextButton(onPressed: recipes.load, child: Text(l.tryAgain)),
          ),
        ),
      ];
    } else if (list.isEmpty && recipes.recipes.isEmpty && inbox.isEmpty) {
      lines = [_Note(text: l.homeEmpty)];
    } else {
      lines = [for (final p in list) PlaceTile(place: p)];
    }

    final recipeLines = <Widget>[
      if (recipes.recipes.isNotEmpty) NotebookHeading(l.recipesHeading),
      for (final r in recipes.recipes)
        NotebookRow(
          mark: Icon(Icons.restaurant_menu, size: 18, color: nb.inkSoft),
          onTap: () => context.push('/recipes/${r.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${l.recipeIngredientCount(r.ingredientCount)} · '
                  '${l.recipeStepCount(r.stepCount)}',
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
              ),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.homeTitle)),
      body: NotebookPage(
        child: RefreshIndicator(
          // Everything on the page: a new recipe or a cleared share shows without a restart.
          onRefresh: () =>
              Future.wait([places.load(), recipes.load(), shared.load()]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [...inbox, ...lines, ...recipeLines],
          ),
        ),
      ),
    );
  }
}

/// A share the server could not read: retry it, or take it off the book.
class _FailedShare extends StatefulWidget {
  const _FailedShare({super.key, required this.share});

  final Share share;

  @override
  State<_FailedShare> createState() => _FailedShareState();
}

class _FailedShareState extends State<_FailedShare> {
  bool _busy = false;

  Future<void> _retry() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shared = context.read<RecentShares>();
    setState(() => _busy = true);
    try {
      await shared.retry(widget.share.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shared = context.read<RecentShares>();
    final ok = await showNotebookDialog(
      context,
      message: l.shareDismissConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.remove,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await shared.dismiss(widget.share.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return NotebookRow(
      mark: Icon(Icons.error_outline, size: 18, color: nb.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.shareFailed),
          // The server's code (unreadable, ai_failed, quota...): what to look up in the logs.
          Text(
            widget.share.reason,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _retry,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(l.tryAgain),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _dismiss,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l.remove),
              ),
            ],
          ),
        ],
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
    return NotebookRow(
      mark: PinMark(pinned: pinned),
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
