import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../shopping_controller.dart';
import 'products_sheet.dart';

/// Account > Brands > Choose a brand: find an ingredient (the shopping list's catalogue names), then its products
/// as a step of the same sheet (the See all sheet, with Back). [onChanged]: after a choice is saved.
Future<void> showBrandAddSheet(
  BuildContext context, {
  VoidCallback? onChanged,
}) => showBaseSheet<void>(
  context,
  builder: (_) => BrandAddSheet(onChanged: onChanged),
);

class BrandAddSheet extends StatefulWidget {
  const BrandAddSheet({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<BrandAddSheet> createState() => _BrandAddSheetState();
}

class _BrandAddSheetState extends State<BrandAddSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<String> _found = const [];
  String? _ingredient; // null = the search step
  bool _forward = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _find(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _found = const []);
      return;
    }
    final shopping = context.read<ShoppingController>();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final found = await shopping
          .suggest(q.trim())
          .catchError((_) => <String>[]);
      if (mounted) setState(() => _found = found.take(8).toList());
    });
  }

  void _open(String? ingredient) => setState(() {
    _forward = ingredient != null;
    _ingredient = ingredient;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final ingredient = _ingredient;
    return SheetSwitcher(
      forward: _forward,
      child: ingredient != null
          ? ProductsSheet(
              key: ValueKey('products-$ingredient'),
              ingredient: ingredient,
              onChanged: widget.onChanged,
              onBack: () => _open(null),
            )
          : ListView(
              key: const ValueKey('search'),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: spaceM),
              children: [
                NotebookRow(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.brandsAdd,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l.brandsAddHint,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ],
                  ),
                ),
                NotebookRow(
                  mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
                  child: TextField(
                    key: const ValueKey('brands-add-query'),
                    controller: _query,
                    autofocus: true,
                    decoration: InputDecoration.collapsed(
                      hintText: l.brandsFindIngredient,
                    ),
                    onChanged: _find,
                  ),
                ),
                for (final name in _found)
                  NotebookRow(
                    key: ValueKey('brands-add-$name'),
                    minHeight: 56,
                    onTap: () => _open(name),
                    trailing: const Icon(Icons.chevron_right),
                    child: Text(name),
                  ),
              ],
            ),
    );
  }
}
