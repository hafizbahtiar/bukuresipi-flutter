import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../owner/domain/owner_repository.dart';
import '../../../shares/domain/share_repository.dart';
import '../../../shares/presentation/recent_shares.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_variant.dart';
import '../recipes_controller.dart';

/// "Recipe variants" under a catalogue dish: other web recipes for it, best match first. Users see the list (nothing
/// when it is empty); the owner also gets "Find variants", which searches the web again (metered) and replaces it,
/// and the dish's required lines most variants leave out, to mark optional (nothing is set without the owner).
class RecipeVariants extends StatefulWidget {
  const RecipeVariants({
    super.key,
    required this.recipe,
    required this.onChanged,
    this.owner = false,
  });

  final RecipeDetail recipe;
  final ValueChanged<RecipeDetail> onChanged;
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
        widget.recipe.id,
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
        widget.recipe.id,
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

  /// Required lines (by position) left out by at least half the variants, with how many: 2+ variants only.
  List<(int, int)> _candidates() {
    if (_variants.length < 2) return const [];
    final lacked = <String, int>{};
    for (final v in _variants) {
      for (final name in v.lacks.map((s) => s.toLowerCase()).toSet()) {
        lacked[name] = (lacked[name] ?? 0) + 1;
      }
    }
    final lines = widget.recipe.ingredients;
    return [
      for (var i = 0; i < lines.length; i++)
        if (!lines[i].optional && lines[i].name != null)
          if (lacked[lines[i].name!.toLowerCase()] case final n?
              when n * 2 >= _variants.length)
            (i, n),
    ];
  }

  Future<void> _markOptional(int index) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await context
          .read<RecipesController>()
          .setIngredientOptional(widget.recipe.id, index, true);
      widget.onChanged(updated);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    if (_variants.isEmpty && !widget.owner) return const SizedBox.shrink();
    final candidates = widget.owner ? _candidates() : const <(int, int)>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.variantsTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceS, spaceXs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _variants.isEmpty ? l.variantsNone : l.variantsHint,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
              // On its own line: beside the hint it left the text no room on a narrow phone.
              if (widget.owner)
                Align(
                  alignment: Alignment.centerRight,
                  child: AiButton(
                    label: l.variantsFind,
                    busy: _finding,
                    onPressed: _find,
                  ),
                ),
            ],
          ),
        ),
        for (final v in _variants) _VariantRow(variant: v),
        if (candidates.isNotEmpty) ...[
          SectionHeader(l.variantsOptionalTitle),
          for (final (index, n) in candidates)
            ListTile(
              title: Text(widget.recipe.ingredients[index].label.toLowerCase()),
              subtitle: Text(
                l.variantsSkippedBy(n, _variants.length),
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
              trailing: TextButton(
                onPressed: () => _markOptional(index),
                child: Text(l.variantsMarkOptional),
              ),
            ),
        ],
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
    return ListTile(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SafeArea(child: _VariantSheet(variant: v)),
      ),
      leading: _MatchBadge(match: v.match),
      trailing: Icon(Icons.chevron_right, color: nb.inkSoft),
      title: Column(
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
        ListTile(
          leading: _MatchBadge(match: v.match),
          title: Column(
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
        SectionHeader(l.recipeIngredients),
        for (final i in v.ingredients)
          ListTile(
            leading: Icon(
              i.name == null ? Icons.help_outline : Icons.link,
              color: i.name == null ? nb.inkSoft : nb.pandanDeep,
            ),
            title: Column(
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
        ListTile(
          leading: Icon(Icons.format_list_numbered, color: nb.inkSoft),
          title: Text(
            v.stepCount > 0
                ? l.variantStepsThere(v.stepCount)
                : l.variantStepsThereUnknown,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(spaceM),
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
