import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_repository.dart';
import '../shopping_controller.dart';

/// Every catalogue product of [ingredient] in the user's order (their brand first, avoided left out), as buying
/// hints; a branded row's next step: use it as their brand for [ingredient], or avoid it or its maker.
Future<void> showProductsSheet(BuildContext context, String ingredient) =>
    showBaseSheet<void>(
      context,
      builder: (_) => ProductsSheet(ingredient: ingredient),
    );

class ProductsSheet extends StatefulWidget {
  const ProductsSheet({super.key, required this.ingredient});

  final String ingredient;

  @override
  State<ProductsSheet> createState() => _ProductsSheetState();
}

class _ProductsSheetState extends State<ProductsSheet> {
  late final Future<List<ShoppingProduct>> _products = context
      .read<ShoppingController>()
      .products(widget.ingredient);
  ShoppingProduct? _picked; // null = the list; else its choices step
  bool _forward = true;

  void _pick(ShoppingProduct? p) => setState(() {
    _forward = p != null;
    _picked = p;
  });

  /// Closes the sheet; the list reloads with the new order. An error is told on the page.
  Future<void> _change(
    Future<void> Function(ShoppingRepository r) change,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopping = context.read<ShoppingController>();
    Navigator.pop(context);
    try {
      await shopping.changeBrands(change);
      messenger.showSnackBar(SnackBar(content: Text(l.brandsSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final p = _picked;
    return SheetSwitcher(
      forward: _forward,
      child: p == null
          ? FutureBuilder(
              key: const ValueKey('list'),
              future: _products,
              builder: (context, s) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: spaceM),
                children: [
                  NotebookRow(
                    child: Text(
                      l.shoppingProductsTitle(widget.ingredient),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (s.hasError)
                    NotebookRow(child: Text(errorText(l, s.error!)))
                  else if (!s.hasData)
                    const Padding(
                      padding: EdgeInsets.all(spaceL),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else
                    for (final p in s.data!)
                      NotebookRow(
                        key: ValueKey('product-${p.name}'),
                        onTap: p.brand == null ? null : () => _pick(p),
                        trailing: p.brand == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name),
                            if (p.brand != null)
                              Text(
                                [
                                  p.brand,
                                  ?p.manufacturer,
                                  ?p.country,
                                ].join(' · '),
                                style: text.bodySmall?.copyWith(
                                  color: nb.inkSoft,
                                ),
                              ),
                            if (p.mine)
                              Padding(
                                padding: const EdgeInsets.only(top: spaceXs),
                                child: TagChip(
                                  TileTag(l.brandsYours, tone: TagTone.good),
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            )
          : Column(
              key: ValueKey('choices-${p.name}'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetStepTitle(title: p.brand!, onBack: () => _pick(null)),
                ListTile(
                  key: const ValueKey('brand-mine'),
                  leading: Icon(p.mine ? Icons.star : Icons.star_outline),
                  title: Text(
                    p.mine
                        ? l.brandsStopUsing(p.brand!, widget.ingredient)
                        : l.brandsUse(p.brand!, widget.ingredient),
                  ),
                  onTap: () => _change(
                    (r) => p.mine
                        ? r.clearMyBrand(widget.ingredient)
                        : r.setMyBrand(widget.ingredient, p.brand!),
                  ),
                ),
                const Divider(height: spaceS),
                ListTile(
                  key: const ValueKey('brand-avoid'),
                  leading: Icon(Icons.block, color: nb.margin),
                  title: Text(
                    l.brandsAvoid(p.brand!),
                    style: TextStyle(color: nb.margin),
                  ),
                  onTap: () =>
                      _change((r) => r.avoid((brand: p.brand, maker: null))),
                ),
                if (p.manufacturer != null)
                  ListTile(
                    key: const ValueKey('maker-avoid'),
                    leading: Icon(Icons.domain_disabled, color: nb.margin),
                    title: Text(
                      l.brandsAvoidMaker(p.manufacturer!),
                      style: TextStyle(color: nb.margin),
                    ),
                    onTap: () => _change(
                      (r) => r.avoid((brand: null, maker: p.manufacturer)),
                    ),
                  ),
                const SizedBox(height: spaceS),
              ],
            ),
    );
  }
}
