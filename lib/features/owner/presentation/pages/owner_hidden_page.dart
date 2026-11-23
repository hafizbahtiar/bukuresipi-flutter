import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Recipes and reviews the owner hid, to show again after a mistake.
class OwnerHiddenPage extends StatefulWidget {
  const OwnerHiddenPage({super.key});

  @override
  State<OwnerHiddenPage> createState() => _OwnerHiddenPageState();
}

class _OwnerHiddenPageState extends State<OwnerHiddenPage> {
  List<HiddenRecipe>? _recipes;
  List<HiddenReview> _reviews = const [];
  final _busy = <String>{};
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hidden = await context.read<OwnerRepository>().hiddenContent();
      if (mounted) {
        setState(() {
          _recipes = hidden.recipes;
          _reviews = hidden.reviews;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _show(String id, {required bool recipe}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<OwnerRepository>();
    final ok = await showBaseDialog(
      context,
      message: recipe ? l.ownerUnhideRecipeConfirm : l.ownerUnhideReviewConfirm,
      confirmLabel: l.ownerUnhide,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await (recipe ? repo.unhideRecipe(id) : repo.unhideReview(id));
      if (mounted) {
        setState(() {
          _recipes = [...?_recipes?.where((r) => r.id != id)];
          _reviews = [..._reviews.where((r) => r.id != id)];
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final recipes = _recipes;
    final date = MaterialLocalizations.of(context).formatShortDate;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.ownerHidden)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: recipes == null
            ? null
            : NotebookPage(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (recipes.isEmpty && _reviews.isEmpty)
                      NotebookRow(
                        minHeight: 110,
                        mark: Icon(
                          Icons.check_circle_outline,
                          color: nb.pandan,
                        ),
                        child: Text(l.ownerHiddenEmpty),
                      ),
                    if (recipes.isNotEmpty)
                      NotebookHeading(l.ownerHiddenRecipes),
                    for (final r in recipes)
                      _HiddenRow(
                        title: r.name,
                        meta: [
                          ?r.owner,
                          l.ownerHiddenOn(date(r.hiddenAt.toLocal())),
                        ].join(' · '),
                        note: r.public ? null : l.ownerHiddenNotPublic,
                        busy: _busy.contains(r.id),
                        onShow: () => _show(r.id, recipe: true),
                      ),
                    if (_reviews.isNotEmpty)
                      NotebookHeading(l.ownerHiddenReviews),
                    for (final r in _reviews)
                      _HiddenRow(
                        title: r.author,
                        meta: [
                          r.place,
                          l.ownerHiddenOn(date(r.hiddenAt.toLocal())),
                        ].join(' · '),
                        stars: r.stars,
                        body: r.text,
                        note: r.text == null ? l.ownerHiddenTextRemoved : null,
                        busy: _busy.contains(r.id),
                        onShow: () => _show(r.id, recipe: false),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HiddenRow extends StatelessWidget {
  const _HiddenRow({
    required this.title,
    required this.meta,
    this.stars,
    this.body,
    this.note,
    required this.busy,
    required this.onShow,
  });

  final String title;
  final String meta;
  final int? stars;
  final String? body;
  final String? note;
  final bool busy;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return NotebookRow(
      mark: Icon(Icons.visibility_off_outlined, size: 18, color: nb.inkSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (stars case final n?)
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= n ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: i <= n ? nb.kunyit : nb.inkSoft,
                  ),
              ],
            ),
          if (body case final b?) ...[
            const SizedBox(height: spaceXs),
            Text(b, style: text.bodyMedium),
          ],
          if (note case final n?)
            Text(
              n,
              style: text.bodySmall?.copyWith(
                color: nb.inkSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(meta, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
          const SizedBox(height: spaceS),
          Align(
            alignment: Alignment.centerRight,
            child: BusyButton(
              icon: Icons.visibility_outlined,
              label: l.ownerUnhide,
              busyLabel: l.ownerUnhiding,
              busy: busy,
              onPressed: onShow,
            ),
          ),
        ],
      ),
    );
  }
}
