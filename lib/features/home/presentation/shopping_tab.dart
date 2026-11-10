import 'package:flutter/material.dart';

import '../../../core/widgets/notebook.dart';
import '../../../core/widgets/pill_switch.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../receipts/presentation/pages/receipts_page.dart';
import '../../shopping/presentation/pages/shopping_page.dart';

/// The Shopping ("Belanja") tab: what to buy (the list) and what was spent (receipts), one switch apart.
class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
  /// Bumped on each switch to Receipts: it loads again (a receipt may have been added meanwhile).
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PillPages<bool>(
      switchKey: const ValueKey('shopping-switch'),
      padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 0, 16, 8),
      initial: false,
      tabs: [
        (false, Icons.checklist, l.shoppingTabList),
        (true, Icons.receipt_long_outlined, l.shoppingTabReceipts),
      ],
      onShown: (receipts) {
        if (receipts) setState(() => _shown++);
      },
      build: (receipts, switcher) => receipts
          ? ReceiptsPage(key: ValueKey(_shown), switcher: switcher)
          : ShoppingPage(switcher: switcher),
    );
  }
}
