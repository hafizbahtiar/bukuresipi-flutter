import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../places/presentation/widgets/owner_panel.dart';

enum _Step { pick, alias, create }

/// One gap, in one sheet ([SheetSwitcher]): pick the ingredient it is, then its other name (with how many lines it
/// links) or a new ingredient. Pops with the lines linked once saved.
class IngredientGapSheet extends StatefulWidget {
  const IngredientGapSheet({
    super.key,
    required this.gap,
    required this.categories,
  });

  final IngredientGap gap;
  final List<String> categories;

  @override
  State<IngredientGapSheet> createState() => _IngredientGapSheetState();
}

class _IngredientGapSheetState extends State<IngredientGapSheet> {
  late final _search = TextEditingController(text: widget.gap.key);
  late final _alias = TextEditingController(text: widget.gap.key);
  late final _name = TextEditingController(
    text: widget.gap.key.isEmpty
        ? ''
        : widget.gap.key[0].toUpperCase() + widget.gap.key.substring(1),
  );
  final _category = TextEditingController();
  _Step _step = _Step.pick;
  bool _forward = true;
  List<String> _found = const [];
  String? _ingredient;
  ({int lines, List<String> sample})? _preview;
  bool _taken = false;
  bool _busy = false;
  ({String? name, String? ingredient, String? category})? _ai;
  bool _aiBusy = false;
  Timer? _debounce;
  int _asked = 0;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _find(_search.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_search, _alias, _name, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step step, {bool forward = true}) => setState(() {
    _forward = forward;
    _step = step;
  });

  /// Catalogue names as the owner types; the gap's own words first ("minyak" finds Minyak masak, Minyak zaitun).
  void _find(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final mine = ++_asked;
      // The server searches 2+ characters; one word of a longer gap still finds its candidates.
      final query = q.trim().length >= 2 ? q.trim() : '';
      final found = query.isEmpty
          ? <String>[]
          : await _repo.searchIngredients(query).catchError((_) => <String>[]);
      if (mounted && mine == _asked) setState(() => _found = found);
    });
  }

  void _pick(String ingredient) {
    _ingredient = ingredient;
    _go(_Step.alias);
    _check(_alias.text);
  }

  /// AI: what the gap's sample line names, and the catalogue ingredient that is. A suggestion: nothing saved.
  Future<void> _suggest() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _aiBusy = true);
    try {
      final ai = await _repo.suggestGap(widget.gap.sample);
      if (mounted) setState(() => _ai = ai);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  /// The AI's name as a new ingredient: the create step, its name (and category, one of ours) filled.
  void _createFromAi(String name, String? category) {
    _name.text = name[0].toUpperCase() + name.substring(1);
    if (category != null && widget.categories.contains(category)) {
      _category.text = category;
    }
    _go(_Step.create);
  }

  /// How many lines the alias would link (nothing saved), or that the name is taken.
  void _check(String alias) {
    _debounce?.cancel();
    setState(() {
      _preview = null;
      _taken = false;
    });
    if (alias.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final mine = ++_asked;
      try {
        final p = await _repo.previewAlias(_ingredient!, alias.trim());
        if (mounted && mine == _asked) setState(() => _preview = p);
      } on ApiException catch (e) {
        if (mounted && mine == _asked && e.code == 'name_taken') {
          setState(() => _taken = true);
        }
      } catch (_) {
        // The preview is a help; Save says what went wrong.
      }
    });
  }

  Future<void> _save(Future<int> Function() save) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final linked = await save();
      if (mounted) Navigator.of(context).pop(linked);
    } on ApiException catch (e) {
      if (e.code == 'name_taken') {
        if (mounted) setState(() => _taken = true);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      }
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
    final text = Theme.of(context).textTheme;
    Widget save(VoidCallback? onPressed) => PanelActions(
      children: [
        BusyButton(
          key: const ValueKey('gap-save'),
          icon: Icons.check,
          label: l.save,
          busyLabel: l.ownerSaving,
          busy: _busy,
          kind: BusyButtonKind.filled,
          onPressed: _busy ? null : onPressed,
        ),
      ],
    );
    // BaseTile keeps the sheet's gutter itself; rows are spaced as the catalogue list.
    Widget row(Widget tile) => Padding(
      padding: const EdgeInsets.only(top: spaceXs),
      child: tile,
    );
    return SheetSwitcher(
      forward: _forward,
      // The sheet caps its height (less with the keyboard up): each step scrolls.
      child: SingleChildScrollView(
        key: ValueKey(_step),
        child: switch (_step) {
          _Step.pick => Column(
            key: const ValueKey('pick'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceM),
                child: Text(
                  l.ownerGapPick(widget.gap.key),
                  style: text.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(spaceM, spaceXs, spaceM, 0),
                child: Text(
                  widget.gap.sample,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AiButton(
                    key: const ValueKey('gap-ai'),
                    label: l.ownerGapAiSuggest,
                    busy: _aiBusy,
                    onPressed: _suggest,
                  ),
                ),
              ),
              if (_ai case final ai?)
                switch (ai) {
                  (name: _, ingredient: final String ingredient, category: _) =>
                    row(
                      BaseTile(
                        key: const ValueKey('gap-ai-same'),
                        leading: const AiBadge(),
                        title: l.ownerGapAiSame(ingredient),
                        dense: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pick(ingredient),
                      ),
                    ),
                  (
                    name: final String name,
                    ingredient: null,
                    :final category,
                  ) =>
                    row(
                      BaseTile(
                        key: const ValueKey('gap-ai-new'),
                        leading: const AiBadge(),
                        title: l.ownerGapAiNew(name),
                        dense: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _createFromAi(name, category),
                      ),
                    ),
                  _ => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      spaceM,
                      spaceS,
                      spaceM,
                      0,
                    ),
                    child: Text(
                      l.ownerGapAiNone,
                      style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                    ),
                  ),
                },
              Padding(
                padding: const EdgeInsets.all(spaceM),
                child: TextField(
                  key: const ValueKey('gap-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: l.ownerGapSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _find,
                ),
              ),
              for (final name in _found.take(6))
                row(
                  BaseTile(
                    key: ValueKey('gap-ingredient-$name'),
                    title: name,
                    dense: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pick(name),
                  ),
                ),
              row(
                BaseTile(
                  key: const ValueKey('gap-new'),
                  leading: const Icon(Icons.add),
                  title: l.ownerGapNew,
                  dense: true,
                  onTap: () => _go(_Step.create),
                ),
              ),
              const SizedBox(height: spaceS),
            ],
          ),
          _Step.alias => Column(
            key: const ValueKey('alias'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetStepTitle(
                title: l.ownerGapAlias(_ingredient ?? ''),
                onBack: () => _go(_Step.pick, forward: false),
              ),
              Padding(
                padding: const EdgeInsets.all(spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('gap-alias'),
                      controller: _alias,
                      decoration: InputDecoration(
                        labelText: l.ownerGapName,
                        errorText: _taken ? l.ownerGapTaken : null,
                      ),
                      onChanged: _check,
                    ),
                    const SizedBox(height: spaceS),
                    if (_preview case final p?) ...[
                      Text(l.ownerGapLinks(p.lines), style: text.titleSmall),
                      for (final s in p.sample.take(3))
                        Text(
                          s,
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
                        ),
                    ],
                    const SizedBox(height: spaceM),
                    save(
                      _taken || _preview == null
                          ? null
                          : () => _save(
                              () => _repo.addAlias(
                                _ingredient!,
                                _alias.text.trim(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Step.create => Column(
            key: const ValueKey('create'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetStepTitle(
                title: l.ownerGapNew,
                onBack: () => _go(_Step.pick, forward: false),
              ),
              Padding(
                padding: const EdgeInsets.all(spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('gap-name'),
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: l.ownerGapName,
                        errorText: _taken ? l.ownerGapTaken : null,
                      ),
                      onChanged: (_) => setState(() => _taken = false),
                    ),
                    const SizedBox(height: spaceS),
                    PickerField(
                      controller: _category,
                      label: l.ownerGapCategory,
                      options: widget.categories,
                      onPicked: (_) => setState(() {}),
                    ),
                    const SizedBox(height: spaceM),
                    ListenableBuilder(
                      listenable: _name,
                      builder: (_, _) => save(
                        _name.text.trim().length < 2 || _category.text.isEmpty
                            ? null
                            : () => _save(
                                () => _repo.addIngredient(
                                  _name.text.trim(),
                                  _category.text,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
