import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../family/presentation/family_controller.dart';
import '../../domain/shopping.dart';
import '../shopping_controller.dart';

/// The Shopping tab: a checklist filled from recipes ("add to list") or typed in.
class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final _text = TextEditingController();
  bool _adding = false;
  Timer? _debounce;
  int _asked = 0;

  /// Catalogue ingredient names for what is being typed (2+ characters).
  List<String> _suggestions = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final asked = ++_asked;
      final found = await context.read<ShoppingController>().suggest(q).catchError((_) => const <String>[]);
      if (!mounted || asked != _asked || _text.text.trim() != q) return; // typed on meanwhile
      setState(() => _suggestions = [
        for (final s in found)
          if (s.toLowerCase() != q.toLowerCase()) s,
      ].take(5).toList());
    });
  }

  Future<void> _addSuggestion(String name) async {
    _text.text = name;
    await _add();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Every action reports its own failure: the list stays as it was.
  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _add() async {
    final text = _text.text.trim();
    if (text.isEmpty || _adding) return;
    setState(() => _adding = true);
    await _run(() async {
      await context.read<ShoppingController>().addText(text);
      _text.clear();
      _asked++; // a suggestion answer still on its way is for the old text
      _suggestions = const [];
    });
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _clearDone() async {
    final l = AppLocalizations.of(context);
    final shopping = context.read<ShoppingController>();
    if (!await showNotebookDialog(
      context,
      message: l.shoppingClearDoneConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.shoppingClearDone,
    )) {
      return;
    }
    await _run(shopping.clearDone);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final shopping = context.watch<ShoppingController>();
    final items = shopping.items;
    final inFamily = context.watch<FamilyController?>()?.inFamily ?? false;
    // Out of the family while on its list: back to the user's own.
    if (!inFamily && shopping.family) {
      WidgetsBinding.instance.addPostFrameCallback((_) => shopping.show(family: false));
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.shoppingTitle),
        actions: [
          if (shopping.anyDone)
            IconButton(
              tooltip: l.shoppingClearDone,
              icon: const Icon(Icons.playlist_remove),
              onPressed: _clearDone,
            ),
        ],
      ),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: shopping.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (inFamily)
                Padding(
                  padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 4, 12, 4),
                  child: NotebookSegmented<bool>(
                    selected: shopping.family,
                    onChanged: (family) => _run(() => shopping.show(family: family)),
                    segments: [
                      NotebookSegment(value: false, label: l.shoppingMine),
                      NotebookSegment(value: true, label: l.shoppingFamily),
                    ],
                  ),
                ),
              NotebookRow(
                mark: Icon(Icons.add, size: 20, color: nb.inkSoft),
                trailing: _adding
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        tooltip: l.shoppingAdd,
                        icon: const Icon(Icons.check),
                        onPressed: _add,
                      ),
                child: TextField(
                  controller: _text,
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  onChanged: _typed,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: l.shoppingAddHint,
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              // Tap a catalogue name to add it as written there (it then links to products).
              for (final name in _suggestions)
                NotebookRow(
                  mark: Icon(Icons.north_west, size: 16, color: nb.inkSoft),
                  onTap: _adding ? null : () => _addSuggestion(name),
                  child: Text(name, style: TextStyle(color: nb.pandanDeep)),
                ),
              if (shopping.error != null && items.isEmpty)
                NotebookRow(
                  mark: Icon(Icons.cloud_off, size: 20, color: nb.margin),
                  onTap: shopping.load,
                  child: Text(l.shoppingLoadFailed),
                )
              else if (shopping.loaded && items.isEmpty)
                NotebookRow(
                  minHeight: 110,
                  mark: Icon(Icons.shopping_basket_outlined, color: nb.inkSoft),
                  child: Text(l.shoppingEmpty),
                ),
              for (final item in items)
                _ItemRow(
                  item: item,
                  onToggle: () =>
                      _run(() => shopping.setDone(item.id, !item.done)),
                  onDelete: () => _run(() => shopping.remove(item.id)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
    final products = item.products
        .map((p) => p.brand == null ? p.name : '${p.name} (${p.brand})')
        .join(', ');
    return NotebookRow(
      onTap: onToggle,
      mark: Checkbox(
        value: item.done,
        onChanged: (_) => onToggle(),
        visualDensity: VisualDensity.compact,
      ),
      trailing: IconButton(
        tooltip: l.remove,
        icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
        onPressed: onDelete,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.text,
            style: item.done
                ? TextStyle(
                    color: nb.inkSoft,
                    decoration: TextDecoration.lineThrough,
                  )
                : null,
          ),
          if (item.recipes.isNotEmpty && !item.done)
            InkWell(
              // One recipe: open it. A summed line names them all.
              onTap: item.recipes.length == 1
                  ? () => context.push('/recipes/${item.recipes.single.id}')
                  : null,
              child: Text(
                l.shoppingFromRecipe(
                  item.recipes.map((r) => r.name).join(', '),
                ),
                style: small,
              ),
            ),
          if (products.isNotEmpty && !item.done)
            InkWell(
              onTap: item.ingredient == null
                  ? null
                  : () => _showProducts(context, item.ingredient!),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: l.shoppingProducts(products)),
                    if (item.ingredient != null)
                      TextSpan(
                        text: '  ${l.shoppingSeeAllProducts}',
                        style: TextStyle(
                          color: nb.pandanDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: small,
              ),
            ),
        ],
      ),
    );
  }
}

/// Every catalogue product of [ingredient]: brand and maker, as buying hints.
Future<void> _showProducts(BuildContext context, String ingredient) {
  final shopping = context.read<ShoppingController>();
  final products = shopping.products(ingredient);
  return showNotebookSheet<void>(
    context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      final nb = Notebook.of(context);
      final text = Theme.of(context).textTheme;
      return FutureBuilder(
        future: products,
        builder: (context, s) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            NotebookRow(
              child: Text(
                l.shoppingProductsTitle(ingredient),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (s.hasError)
              NotebookRow(child: Text(errorText(l, s.error!)))
            else if (!s.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              for (final p in s.data!)
                NotebookRow(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name),
                      if (p.brand != null)
                        Text(
                          [p.brand, ?p.manufacturer].join(' · '),
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      );
    },
  );
}
