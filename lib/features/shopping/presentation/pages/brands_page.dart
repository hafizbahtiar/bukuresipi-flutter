import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../shopping_controller.dart';

/// Account > Brands: how the shopping list's product hints are ordered for this user (only they see it).
/// Server design: bukuresipi-hono docs/superpowers/specs/2026-11-26-brands-design.md.
class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  bool _saving = false;

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
            ],
          ),
        ),
      ),
    );
  }
}
