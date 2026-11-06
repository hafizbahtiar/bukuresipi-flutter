import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../owner/domain/owner_repository.dart';
import '../../../shares/domain/share_repository.dart';
import '../../../shares/presentation/recent_shares.dart';
import '../../domain/recipe_variant.dart';
import '../recipes_controller.dart';

/// "Recipe variants" under a catalogue dish: other web recipes for it, best match first. Users see the list (nothing
/// when it is empty); the owner also gets "Find variants", which searches the web again (metered) and replaces it.
class RecipeVariants extends StatefulWidget {
  const RecipeVariants({super.key, required this.recipeId, this.owner = false});

  final String recipeId;
  final bool owner;

  @override
  State<RecipeVariants> createState() => _RecipeVariantsState();
}

class _RecipeVariantsState extends State<RecipeVariants> {
  List<RecipeVariant> _variants = const [];
  bool _finding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<RecipesController>().variants(
        widget.recipeId,
      );
      if (mounted) setState(() => _variants = list);
    } catch (_) {
      // Extra reading only: the recipe page works without it.
    }
  }

  Future<void> _find() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _finding = true);
    try {
      final found = await context.read<OwnerRepository>().findVariants(
        widget.recipeId,
      );
      if (!mounted) return;
      setState(() => _variants = found.variants);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            found.complete
                ? l.variantsFound(found.variants.length)
                : l.variantsIncomplete,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    if (_variants.isEmpty && !widget.owner) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NotebookHeading(l.variantsTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _variants.isEmpty ? l.variantsNone : l.variantsHint,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
              if (widget.owner)
                TextButton.icon(
                  onPressed: _finding ? null : _find,
                  icon: _finding
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore, size: 18),
                  label: Text(l.variantsFind),
                ),
            ],
          ),
        ),
        for (final v in _variants) _VariantRow(variant: v),
      ],
    );
  }
}

String _pct(double p) => '${(p * 100).round()}%';

String _lang(String? code) => code?.toUpperCase() ?? '?';

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant});

  final RecipeVariant variant;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final v = variant;
    return NotebookRow(
      onTap: () => showNotebookSheet<void>(
        context,
        builder: (_) => _VariantSheet(variant: v),
      ),
      mark: _MatchBadge(match: v.match),
      trailing: Icon(Icons.chevron_right, color: nb.inkSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v.title ?? v.site,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              v.site,
              _lang(v.lang),
              if (v.stepCount > 0) l.variantSteps(v.stepCount),
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          if (v.adds.isNotEmpty || v.lacks.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  if (v.adds.isNotEmpty)
                    TextSpan(
                      text:
                          '+ ${v.adds.map((s) => s.toLowerCase()).join(', ')}  ',
                      style: TextStyle(color: nb.pandanDeep),
                    ),
                  if (v.lacks.isNotEmpty)
                    TextSpan(
                      text:
                          '− ${v.lacks.map((s) => s.toLowerCase()).join(', ')}',
                      style: TextStyle(color: nb.margin),
                    ),
                ],
              ),
              style: text.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Clef's "same dish?" as a small round percentage.
class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.match});

  final double match;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final color = match >= 0.85 ? nb.pandanDeep : nb.kunyit;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        _pct(match),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// One variant: its ingredient lines with what each is linked to and how sure, then open it or save it to the book
/// (the usual share pipeline reads it into the user's own copy, steps included).
class _VariantSheet extends StatelessWidget {
  const _VariantSheet({required this.variant});

  final RecipeVariant variant;

  Future<void> _save(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recent = context.read<RecentShares?>();
    try {
      await context.read<ShareRepository>().submitLink(variant.url);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.shareSavedLeaving)));
      await recent?.load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final v = variant;
    return ListView(
      shrinkWrap: true,
      children: [
        NotebookRow(
          mark: _MatchBadge(match: v.match),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.title ?? v.site,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                [
                  v.site,
                  _lang(v.lang),
                  l.variantMatch(_pct(v.match)),
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
        ),
        NotebookHeading(l.recipeIngredients),
        for (final i in v.ingredients)
          NotebookRow(
            mark: Icon(
              i.name == null ? Icons.help_outline : Icons.link,
              size: 18,
              color: i.name == null ? nb.inkSoft : nb.pandanDeep,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.text),
                Text(
                  i.name == null
                      ? l.variantUnlinked
                      : [
                          i.name!.toLowerCase(),
                          if (i.confidence != null && i.confidence! < 1)
                            l.variantSure(_pct(i.confidence!)),
                        ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: i.name == null ? nb.inkSoft : nb.pandanDeep,
                  ),
                ),
              ],
            ),
          ),
        NotebookRow(
          mark: Icon(Icons.format_list_numbered, size: 18, color: nb.inkSoft),
          child: Text(
            v.stepCount > 0
                ? l.variantStepsThere(v.stepCount)
                : l.variantStepsThereUnknown,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => openLink(context, v.url, failed: l.openFailed),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l.variantOpen),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => _save(context),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(l.variantSave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
