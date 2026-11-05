import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../recipes_controller.dart';

/// Picks the catalogue ingredient for a recipe line. null = cancelled; `(name: null)` = unlink the line.
Future<({String? name})?> pickIngredient(
  BuildContext context, {
  required String line,
  required bool linked,
}) => showNotebookSheet<({String? name})>(
  context,
  builder: (_) => _IngredientPicker(line: line, linked: linked),
);

class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({required this.line, required this.linked});

  final String line;
  final bool linked;

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
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      children: [
        NotebookRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.ingredientPickTitle,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                widget.line,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
        ),
        NotebookRow(
          mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
          child: TextField(
            autofocus: true,
            maxLength: 50,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: l.ingredientSearchHint,
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        if (_failed)
          NotebookRow(
            child: Text(l.errNetwork, style: TextStyle(color: nb.margin)),
          ),
        for (final name in _names)
          NotebookRow(
            onTap: () => Navigator.of(context).pop((name: name)),
            child: Text(name),
          ),
        if (widget.linked)
          NotebookRow(
            mark: Icon(Icons.link_off, size: 20, color: nb.margin),
            onTap: () => Navigator.of(context).pop((name: null)),
            child: Text(l.ingredientUnlink, style: TextStyle(color: nb.margin)),
          ),
      ],
    );
  }
}
