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
/// A choice is saved, then the sheet slides back to the list, reloaded (the new order and tags say it worked).
/// [onChanged]: after a choice is saved (the shopping list reloads itself).
Future<void> showProductsSheet(
  BuildContext context,
  String ingredient, {
  VoidCallback? onChanged,
}) => showBaseSheet<void>(
  context,
  builder: (_) => ProductsSheet(ingredient: ingredient, onChanged: onChanged),
);

class ProductsSheet extends StatefulWidget {
  const ProductsSheet({
    super.key,
    required this.ingredient,
    this.onChanged,
    this.onBack,
  });

  final String ingredient;
  final VoidCallback? onChanged;

  /// Shown as a step of another sheet (Account > Brands > +): its title gets Back to that sheet's step before.
  final VoidCallback? onBack;

  @override
  State<ProductsSheet> createState() => _ProductsSheetState();
}

class _ProductsSheetState extends State<ProductsSheet> {
  late Future<List<ShoppingProduct>> _products = context
      .read<ShoppingController>()
      .products(widget.ingredient);
  ShoppingProduct? _picked; // null = the list; else its choices step
  bool _forward = true;

  void _pick(ShoppingProduct? p) => setState(() {
    _forward = p != null;
    _picked = p;
  });

  /// Back to the list, which waits for the change and then reloads; a failed change shows there.
  void _change(Future<void> Function(ShoppingRepository r) change) {
    final shopping = context.read<ShoppingController>();
    final onChanged = widget.onChanged;
    setState(() {
      _products = () async {
        await shopping.changeBrands(change);
        onChanged?.call();
        return shopping.products(widget.ingredient);
      }();
      _forward = false;
      _picked = null;
    });
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
                  if (widget.onBack case final back?)
                    SheetStepTitle(
                      title: l.shoppingProductsTitle(widget.ingredient),
                      onBack: back,
                    )
                  else
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
                  else if (s.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(spaceL),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (s.data!.isEmpty)
                    NotebookRow(
                      child: Text(
                        l.brandsNoProducts,
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
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
                NotebookRow(
                  key: const ValueKey('brand-mine'),
                  minHeight: 56,
                  mark: Icon(p.mine ? Icons.star : Icons.star_outline),
                  onTap: () => _change(
                    (r) => p.mine
                        ? r.clearMyBrand(widget.ingredient)
                        : r.setMyBrand(widget.ingredient, p.brand!),
                  ),
                  child: Text(
                    p.mine
                        ? l.brandsStopUsing(p.brand!, widget.ingredient)
                        : l.brandsUse(p.brand!, widget.ingredient),
                  ),
                ),
                NotebookRow(
                  key: const ValueKey('brand-avoid'),
                  minHeight: 56,
                  mark: Icon(Icons.block, color: nb.margin),
                  onTap: () =>
                      _change((r) => r.avoid((brand: p.brand, maker: null))),
                  child: Text(
                    l.brandsAvoid(p.brand!),
                    style: TextStyle(color: nb.margin),
                  ),
                ),
                if (p.manufacturer != null)
                  NotebookRow(
                    key: const ValueKey('maker-avoid'),
                    minHeight: 56,
                    mark: Icon(Icons.domain_disabled, color: nb.margin),
                    onTap: () => _change(
                      (r) => r.avoid((brand: null, maker: p.manufacturer)),
                    ),
                    child: Text(
                      l.brandsAvoidMaker(p.manufacturer!),
                      style: TextStyle(color: nb.margin),
                    ),
                  ),
                const SizedBox(height: spaceS),
              ],
            ),
    );
  }
}
