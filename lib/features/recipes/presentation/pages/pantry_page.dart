import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
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

class _PantryPageState extends State<PantryPage> {
  final _field = TextEditingController();
  List<String> _have = [];
  bool _staples = true;
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _query = 0;
  List<PantryMatch>? _results;
  bool _finding = false;

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

  void _add(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    setState(() {
      if (!_have.any((h) => h.toLowerCase() == n.toLowerCase())) {
        _have = [..._have, n];
      }
      _field.clear();
      _suggestions = const [];
    });
    _remember();
  }

  void _remove(String name) {
    setState(() => _have = _have.where((h) => h != name).toList());
    _remember();
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
      if (mounted) setState(() => _results = r);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _addMissing(PantryMatch m) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopping = context.read<ShoppingController>();
    try {
      for (final name in m.missing) {
        await shopping.addText(name);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.pantryAdded)));
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
                    InputChip(label: Text(h), onDeleted: () => _remove(h)),
                ],
              ),
            ),
          SwitchListTile(
            value: _staples,
            title: Text(l.pantryStaples),
            onChanged: (v) {
              setState(() => _staples = v);
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
          if (results != null && results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(spaceM),
              child: Text(
                l.pantryNone,
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
          if (results != null)
            for (final m in results)
              ListTile(
                key: ValueKey('pantry-${m.recipe.id}'),
                onTap: () => context.push('/recipes/${m.recipe.id}'),
                title: Text(m.recipe.name, style: text.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.missing.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TagChip(TileTag(l.pantryCookNow)),
                      )
                    else
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
