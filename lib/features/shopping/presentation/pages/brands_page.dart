import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_repository.dart';
import '../shopping_controller.dart';

/// Account > Brands: how the shopping list's product hints are ordered for this user (only they see it): their
/// brand per ingredient, brands and makers avoided (both chosen on a line's See all), Malaysian brands first.
/// Server design: bukuresipi-hono docs/superpowers/specs/2026-11-26-brands-design.md.
class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  bool _saving = false;
  BrandChoices? _choices;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await context.read<ShoppingController>().brandChoices();
      if (!mounted) return;
      setState(() {
        _choices = c;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _remove(
    Future<void> Function(ShoppingRepository r) change,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await context.read<ShoppingController>().changeBrands(change);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLocalFirst(bool on) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shopping = context.read<ShoppingController>();
    setState(() => _saving = true);
    try {
      await context.read<AuthController>().setLocalFirst(on);
      // The hints are ordered by the server: read the list again.
      shopping.load().ignore();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final user = context.watch<AuthController>().user;
    final c = _choices;
    Widget remove(
      String key,
      Future<void> Function(ShoppingRepository r) change,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: l.brandsRemove,
      icon: const Icon(Icons.close),
      onPressed: _saving ? null : () => _remove(change),
    );
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.brandsTitle)),
      body: WidePage(
        // Its own Material: WidePage's page colour would hide the switch row's ink.
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.only(bottom: spaceL),
            children: [
              SwitchListTile(
                key: const ValueKey('brands-local-first'),
                value: user?.localFirst ?? false,
                title: Text(l.brandsLocalFirst),
                subtitle: Text(
                  l.brandsLocalFirstHint,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
                onChanged: _saving || user == null ? null : _setLocalFirst,
              ),
              if (c == null)
                SizedBox(
                  height: 160,
                  child: LoadView(
                    loading: _error == null,
                    error: _error,
                    onReload: _load,
                    child: null,
                  ),
                )
              else ...[
                SectionHeader(l.brandsMine),
                if (c.mine.isEmpty && c.avoid.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: spaceM),
                    child: Text(
                      l.brandsNone,
                      style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                    ),
                  ),
                for (final m in c.mine)
                  BaseTile(
                    key: ValueKey('brands-mine-${m.ingredient}'),
                    dense: true,
                    title: m.brand,
                    subtitle: m.ingredient,
                    trailing: remove(
                      'brands-mine-remove-${m.ingredient}',
                      (r) => r.clearMyBrand(m.ingredient),
                    ),
                  ),
                if (c.avoid.isNotEmpty) ...[
                  SectionHeader(l.brandsAvoided),
                  for (final a in c.avoid)
                    BaseTile(
                      key: ValueKey('brands-avoid-${a.brand ?? a.maker}'),
                      dense: true,
                      title: a.brand ?? a.maker!,
                      subtitle: a.brand == null ? l.brandsWholeMaker : null,
                      trailing: remove(
                        'brands-unavoid-${a.brand ?? a.maker}',
                        (r) => r.unavoid(a),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
