import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_constant.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../recipes_controller.dart';

/// What the user chose for a recipe line: a catalogue [name] to link it to (null = unlink), or, when [optional] is
/// set, only that mark (the link is left alone).
typedef LineChoice = ({String? name, bool? optional});

/// Picks the catalogue ingredient for a recipe line, or flips its "optional" mark. null = cancelled.
Future<LineChoice?> pickIngredient(
  BuildContext context, {
  required String line,
  required bool linked,
  required bool optional,
}) => showModalBottomSheet<LineChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(
    child: _IngredientPicker(line: line, linked: linked, optional: optional),
  ),
);

class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({
    required this.line,
    required this.linked,
    required this.optional,
  });

  final String line;
  final bool linked;
  final bool optional;

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  Timer? _debounce;
  List<String> _names = const [];
  bool _failed = false;
  int _query = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) return setState(() => _names = const []);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final mine = ++_query;
      try {
        final names = await context.read<RecipesController>().searchIngredients(
          q,
        );
        if (mounted && mine == _query) {
          setState(() {
            _names = names;
            _failed = false;
          });
        }
      } catch (_) {
        if (mounted && mine == _query) setState(() => _failed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + spaceM,
      ),
      children: [
        ListTile(
          title: Text(
            l.ingredientPickTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(widget.line),
        ),
        SwitchListTile(
          key: const ValueKey('ingredient-optional'),
          value: widget.optional,
          onChanged: (on) =>
              Navigator.of(context).pop((name: null, optional: on)),
          title: Text(l.recipeOptional),
          subtitle: Text(l.recipeOptionalHint),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: spaceM),
          child: TextField(
            autofocus: true,
            maxLength: 50,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: l.ingredientSearchHint,
              prefixIcon: const Icon(Icons.search),
              counterText: '',
            ),
          ),
        ),
        if (_failed)
          ListTile(
            title: Text(l.errNetwork, style: TextStyle(color: error)),
          ),
        for (final name in _names)
          ListTile(
            onTap: () =>
                Navigator.of(context).pop((name: name, optional: null)),
            title: Text(name),
          ),
        if (widget.linked)
          ListTile(
            leading: Icon(Icons.link_off, color: error),
            onTap: () =>
                Navigator.of(context).pop((name: null, optional: null)),
            title: Text(l.ingredientUnlink, style: TextStyle(color: error)),
          ),
      ],
    );
  }
}
