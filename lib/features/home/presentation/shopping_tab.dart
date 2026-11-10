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
  bool _receipts = false;

  /// Bumped on each switch to Receipts: it loads again (a receipt may have been added meanwhile).
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final height = MediaQuery.textScalerOf(context).scale(40) + 12;
    final switcher = PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 0, 16, 8),
        child: PillSwitch<bool>(
          key: const ValueKey('shopping-switch'),
          value: _receipts,
          expand: true,
          onChanged: (r) => setState(() {
            _receipts = r;
            if (r) _shown++;
          }),
          options: [
            (false, _Label(Icons.checklist, l.shoppingTabList), null),
            (
              true,
              _Label(Icons.receipt_long_outlined, l.shoppingTabReceipts),
              null,
            ),
          ],
        ),
      ),
    );
    return IndexedStack(
      index: _receipts ? 1 : 0,
      children: [
        ShoppingPage(switcher: switcher),
        ReceiptsPage(key: ValueKey(_shown), switcher: switcher),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}
