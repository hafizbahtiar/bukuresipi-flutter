import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Owner > Ingredient gaps > ⋮ > Suggest aliases with AI: the AI's aliases, none ticked (a wrong alias links
/// allergens, so each is a choice), the ones that link lines now first; the owner ticks the right ones and saves them (as by hand: relinked, in Copy rows). Pops with (aliases saved, lines linked).
/// Server: bukuresipi-hono docs/superpowers/specs/2026-11-26-catalogue-ai-ingredients-design.md.
class AliasSuggestSheet extends StatefulWidget {
  const AliasSuggestSheet({super.key});

  @override
  State<AliasSuggestSheet> createState() => _AliasSuggestSheetState();
}

class _AliasSuggestSheetState extends State<AliasSuggestSheet> {
  List<AliasSuggestion> _items = const [];
  final _on = <AliasSuggestion>{};
  int? _next = 0;
  Object? _error;
  bool _loading = false;
  bool _saving = false;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _more();
  }

  /// The next 20 ingredients' aliases, added below.
  Future<void> _more() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.suggestAliases(_next!);
      if (mounted) {
        setState(() {
          // The ones that link lines now first; earlier rows stay where the owner saw them.
          _items = [
            ..._items,
            ...[...r.items]..sort((a, b) => b.lines.compareTo(a.lines)),
          ];
          _next = r.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// All ticked rows in one call (one relink on the server); taken names are skipped there.
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final r = await _repo.addAliases([
        for (final s in _on) (ingredient: s.ingredient, alias: s.alias),
      ]);
      if (mounted) Navigator.of(context).pop((r.saved, r.linked));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(AliasSuggestion s) =>
      setState(() => _on.contains(s) ? _on.remove(s) : _on.add(s));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final ticked = _on.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l.ownerAliasAiTitle, style: text.titleMedium),
              ),
              const AiBadge(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceXs, spaceM, spaceS),
          child: Text(
            l.ownerAliasAiHint,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ),
        if (_items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceS),
              child: TextButton(
                key: const ValueKey('alias-ai-all'),
                onPressed: _saving
                    ? null
                    : () => setState(
                        () => ticked == _items.length
                            ? _on.clear()
                            : _on.addAll(_items),
                      ),
                child: Text(
                  ticked == _items.length
                      ? l.ownerAliasAiTickNone
                      : l.ownerAliasAiTickAll,
                ),
              ),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in _items)
                NotebookRow(
                  key: ValueKey('alias-ai-${s.alias}'),
                  onTap: _saving ? null : () => _toggle(s),
                  mark: Checkbox(
                    value: _on.contains(s),
                    onChanged: _saving ? null : (_) => _toggle(s),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.alias}  →  ${s.ingredient}'),
                      Text(
                        l.ownerAliasAiLines(s.lines),
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ],
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(spaceL),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_error != null)
                ListTile(
                  title: Text(errorText(l, _error!)),
                  trailing: TextButton(
                    onPressed: _more,
                    child: Text(l.tryAgain),
                  ),
                )
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(spaceM),
                  child: Text(
                    l.ownerAliasAiNone,
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(spaceM),
          child: PanelActions(
            children: [
              if (_next != null)
                BusyButton(
                  key: const ValueKey('alias-ai-more'),
                  icon: Icons.expand_more,
                  label: l.loadMore,
                  busyLabel: l.loadMore,
                  busy: _loading && _items.isNotEmpty,
                  kind: BusyButtonKind.outlined,
                  onPressed: _loading || _saving ? null : _more,
                ),
              BusyButton(
                key: const ValueKey('alias-ai-save'),
                icon: Icons.check,
                label: l.ownerAliasAiSave(ticked),
                busyLabel: l.ownerSaving,
                busy: _saving,
                kind: BusyButtonKind.filled,
                onPressed: ticked == 0 || _saving || _loading ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
