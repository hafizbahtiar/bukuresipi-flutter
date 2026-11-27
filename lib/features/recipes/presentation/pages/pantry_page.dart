import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../shopping/presentation/shopping_controller.dart';
import '../../domain/recipe.dart';
import '../recipes_controller.dart';

/// What can I cook?: the user lists what is in the kitchen (kept on this phone only), the server ranks the recipes
/// they can read: cook now first, then the ones missing 1-3 things, which can go to the shopping list.
class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

const _key = 'pantry.ingredients';

const _staplesKey = 'pantry.staples';

/// What the user said they have (What can I cook?), kept on this phone, and whether salt, sugar, oil and water count;
/// empty when nothing or the store fails.
Future<({List<String> have, bool staples})> pantryIngredients() async {
  try {
    final p = await SharedPreferences.getInstance();
    return (
      have: p.getStringList(_key) ?? <String>[],
      staples: p.getBool(_staplesKey) ?? true,
    );
  } catch (_) {
    return (have: <String>[], staples: true);
  }
}

class _PantryPageState extends State<PantryPage> {
  final _field = TextEditingController();
  List<String> _have = [];
  bool _staples = true;
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _query = 0;
  List<PantryMatch>? _results;
  Set<String> _unrecognised = const {};
  bool _finding = false;
  List<DishSuggestion>? _dishes;
  bool _suggesting = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  // Per-phone convenience only: an empty or blocked store just starts empty.
  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _have = p.getStringList(_key) ?? [];
        _staples = p.getBool(_staplesKey) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _remember() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, _have);
      await p.setBool(_staplesKey, _staples);
    } catch (_) {}
  }

  void _suggest(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final mine = ++_query;
      try {
        final names = await context.read<RecipesController>().searchIngredients(
          q,
        );
        if (mounted && mine == _query) {
          setState(() => _suggestions = names.take(5).toList());
        }
      } catch (_) {
        // A hint only: typing goes on without it.
      }
    });
  }

  // The API's limits (POST /recipes/from-pantry): 30 names of up to 50 characters.
  static const _maxItems = 30;
  static const _maxName = 50;

  void _add(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    final known = _have.any((h) => h.toLowerCase() == n.toLowerCase());
    if (!known && _have.length >= _maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pantryFull)),
      );
      return;
    }
    setState(() {
      if (!_have.any((h) => h.toLowerCase() == n.toLowerCase())) {
        _have = [..._have, n];
        _stale();
      }
      _field.clear();
      _suggestions = const [];
    });
    _remember();
  }

  void _remove(String name) {
    setState(() {
      _have = _have.where((h) => h != name).toList();
      _stale();
    });
    _remember();
  }

  /// The list changed: the last answer no longer says what it can cook (called inside setState).
  void _stale() {
    _results = null;
    _dishes = null;
  }

  Future<void> _find() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _finding = true);
    try {
      final r = await context.read<RecipesController>().fromPantry(
        _have,
        staples: _staples,
      );
      if (mounted) {
        setState(() {
          _results = r.items;
          _unrecognised = {for (final u in r.unrecognised) u.toLowerCase()};
          _dishes = null;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  /// Nothing fits: dish names from AI (no recipe made up); a tap searches the web for one.
  Future<void> _suggestDishes() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _suggesting = true);
    try {
      final d = await context.read<RecipesController>().suggestDishes(_have);
      if (mounted) setState(() => _dishes = d);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _addMissing(PantryMatch m) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopping = context.read<ShoppingController>();
    try {
      // The recipe's own lines (amounts as written), less what the kitchen has: the server's same rule as the match.
      final added = await shopping.addRecipe(
        m.recipe.id,
        family: shopping.family,
        skipOptional: true,
        have: _have,
        staples: _staples,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0 ? l.shoppingAlreadyAdded : l.shoppingAdded(added),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: NotebookTitle(l.pantryTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: spaceL),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
            child: Text(
              l.pantryHint,
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
            child: TextField(
              key: const ValueKey('pantry-field'),
              controller: _field,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(_maxName)],
              decoration: InputDecoration(
                labelText: l.pantryAdd,
                suffixIcon: IconButton(
                  tooltip: l.pantryAdd,
                  onPressed: () => _add(_field.text),
                  icon: const Icon(Icons.add),
                ),
              ),
              onChanged: _suggest,
              onSubmitted: _add,
            ),
          ),
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, spaceXs, spaceM, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final s in _suggestions)
                    ActionChip(label: Text(s), onPressed: () => _add(s)),
                ],
              ),
            ),
          if (_have.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final h in _have)
                    InputChip(
                      avatar: _unrecognised.contains(h.toLowerCase())
                          ? Icon(Icons.help_outline, color: nb.inkSoft)
                          : null,
                      label: Text(h),
                      onDeleted: () => _remove(h),
                    ),
                ],
              ),
            ),
          if (_have.any((h) => _unrecognised.contains(h.toLowerCase())))
            Padding(
              key: const ValueKey('pantry-unrecognised'),
              padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
              child: Text(
                l.pantryUnrecognised,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ),
          SwitchListTile(
            value: _staples,
            title: Text(l.pantryStaples),
            onChanged: (v) {
              setState(() {
                _staples = v;
                _stale();
              });
              _remember();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spaceM),
            child: FilledButton.icon(
              key: const ValueKey('pantry-find'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _have.isEmpty || _finding ? null : _find,
              icon: _finding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(l.pantryFind),
            ),
          ),
          if (results != null && results.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(spaceM),
              child: Text(
                l.pantryNone,
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
            if (_dishes == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceM),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AiButton(
                    key: const ValueKey('pantry-suggest'),
                    label: l.pantrySuggest,
                    busy: _suggesting,
                    onPressed: _suggestDishes,
                  ),
                ),
              )
            else if (_dishes!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceM),
                child: Text(
                  l.pantrySuggestNone,
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceM),
                child: Text(
                  l.pantrySuggestNote,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
              for (final d in _dishes!)
                ListTile(
                  key: ValueKey('pantry-dish-${d.name}'),
                  leading: const AiBadge(),
                  title: Text(d.name, style: text.titleMedium),
                  subtitle: Text(l.pantryUses(d.uses.join(', '))),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => openLink(
                    context,
                    'https://www.google.com/search?q=${Uri.encodeQueryComponent('resepi ${d.name}')}',
                    failed: l.openFailed,
                  ),
                ),
            ],
          ],
          if (results != null)
            for (final m in results)
              ListTile(
                key: ValueKey('pantry-${m.recipe.id}'),
                onTap: () => context.push('/recipes/${m.recipe.id}'),
                title: Text(m.recipe.name, style: text.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lines to check may be anything: only a recipe with none is "cook now".
                    if (m.missing.isEmpty && m.unknown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TagChip(TileTag(l.pantryCookNow)),
                      )
                    else if (m.missing.isNotEmpty)
                      Text(l.pantryMissing(m.missing.join(', '))),
                    if (m.unknown.isNotEmpty)
                      Text(
                        l.pantryCheck(m.unknown.join(', ')),
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                  ],
                ),
                trailing: m.missing.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.pantryAddMissing,
                        onPressed: () => _addMissing(m),
                        icon: const Icon(Icons.add_shopping_cart),
                      ),
              ),
        ],
      ),
    );
  }
}
