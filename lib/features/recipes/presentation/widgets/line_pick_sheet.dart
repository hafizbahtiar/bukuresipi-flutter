import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';

/// What the author chose for a line in [showLinePickSheet].
sealed class LinePickResult {}

class Picked extends LinePickResult {
  Picked(this.pick);
  final LinePick pick;
}

class Suggested extends LinePickResult {
  Suggested(this.name);
  final String name;
}

/// The recipe editor's pick for one line: [ingredient]'s products (null = an unlinked line: brands only), a brand
/// search, and "Suggest it" for a brand the catalogue lacks (only for a saved, unchanged [line] of recipe [recipeId]).
Future<LinePickResult?> showLinePickSheet(
  BuildContext context, {
  String? ingredient,
  String? recipeId,
  required String line,
}) => showBaseSheet<LinePickResult>(
  context,
  builder: (_) =>
      LinePickSheet(ingredient: ingredient, recipeId: recipeId, line: line),
);

class LinePickSheet extends StatefulWidget {
  const LinePickSheet({
    super.key,
    this.ingredient,
    this.recipeId,
    required this.line,
  });

  final String? ingredient;
  final String? recipeId;
  final String line;

  @override
  State<LinePickSheet> createState() => _LinePickSheetState();
}

class _LinePickSheetState extends State<LinePickSheet> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  Timer? _debounce;
  List<LinePick> _products = const [];
  List<LinePick> _brands = const [];
  bool _suggesting = false;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.ingredient case final ingredient?) {
      context
          .read<RecipesController>()
          .picks(ingredient: ingredient)
          .then((c) {
            if (mounted) setState(() => _products = c.products);
          })
          .catchError((Object e) {
            if (mounted) setState(() => _error = e);
          });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  void _find(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _brands = const []);
      return;
    }
    final recipes = context.read<RecipesController>();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final found = await recipes
          .picks(query: q.trim())
          .catchError((_) => (products: <LinePick>[], brands: <LinePick>[]));
      if (mounted) setState(() => _brands = found.brands);
    });
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    if (name.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<RecipesController>().suggestPick(
        widget.recipeId!,
        widget.line,
        name,
      );
      if (mounted) Navigator.of(context).pop(Suggested(name));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  Widget _row(LinePick p, String title) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final about = [if (!p.isBrand) ?p.brand, ?p.maker, ?p.country].join(' · ');
    return NotebookRow(
      key: ValueKey('pick-${p.kind}-${p.id}'),
      minHeight: 56,
      onTap: () => Navigator.of(context).pop(Picked(p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (about.isNotEmpty)
            Text(about, style: small?.copyWith(color: nb.inkSoft)),
          if (p.mine || p.avoided)
            Padding(
              padding: const EdgeInsets.only(top: spaceXs),
              child: Wrap(
                spacing: spaceXs,
                children: [
                  if (p.mine)
                    TagChip(TileTag(l.brandsYours, tone: TagTone.good)),
                  if (p.avoided)
                    TagChip(TileTag(l.brandsAvoided, tone: TagTone.danger)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final error = _error;
    return SheetSwitcher(
      forward: _suggesting,
      child: _suggesting
          ? ListView(
              key: const ValueKey('suggest'),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: spaceM),
              children: [
                SheetStepTitle(
                  title: l.recipePickSuggest,
                  onBack: () => setState(() => _suggesting = false),
                ),
                NotebookRow(
                  child: Text(
                    l.recipePickSuggestHint,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ),
                NotebookRow(
                  child: TextField(
                    key: const ValueKey('pick-suggest-name'),
                    controller: _name,
                    autofocus: true,
                    maxLength: 60,
                    decoration: InputDecoration(
                      hintText: l.recipePickSuggestName,
                      counterText: '',
                      errorText: error == null ? null : errorText(l, error),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: spaceM),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _busy ? null : _send,
                      child: Text(l.recipePickSend),
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              key: const ValueKey('list'),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: spaceM),
              children: [
                NotebookRow(
                  child: Text(
                    l.recipePickTitle,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final p in _products) _row(p, p.name),
                NotebookRow(
                  mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
                  child: TextField(
                    key: const ValueKey('pick-query'),
                    controller: _query,
                    decoration: InputDecoration.collapsed(
                      hintText: l.recipePickSearch,
                    ),
                    onChanged: _find,
                  ),
                ),
                for (final b in _brands) _row(b, l.recipePickAny(b.name)),
                if (widget.recipeId != null)
                  NotebookRow(
                    key: const ValueKey('pick-suggest'),
                    mark: Icon(
                      Icons.add_comment_outlined,
                      size: 20,
                      color: nb.inkSoft,
                    ),
                    onTap: () => setState(() {
                      _suggesting = true;
                      _error = null;
                    }),
                    trailing: const Icon(Icons.chevron_right),
                    child: Text(l.recipePickSuggest),
                  ),
              ],
            ),
    );
  }
}
