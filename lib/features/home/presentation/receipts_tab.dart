import 'package:flutter/material.dart';

import '../../../core/widgets/notebook.dart';
import '../../../core/widgets/pill_switch.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../receipts/presentation/pages/calories_page.dart';
import '../../receipts/presentation/pages/receipts_page.dart';

/// The Receipts tab: spending and receipts, with calories one switch away.
class ReceiptsTab extends StatefulWidget {
  const ReceiptsTab({super.key});

  @override
  State<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<ReceiptsTab> {
  /// Bumped on each switch: the page shown loads again in place (a receipt may have been added meanwhile).
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PillPages<bool>(
      switchKey: const ValueKey('receipts-switch'),
      padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 0, 16, 8),
      initial: false,
      tabs: [
        (false, Icons.receipt_long_outlined, l.navReceipts),
        (true, Icons.local_fire_department_outlined, l.navCalories),
      ],
      onShown: (_) {
        setState(() => _shown++);
      },
      build: (calories, switcher) => calories
          ? CaloriesPage(switcher: switcher, refresh: _shown)
          : ReceiptsPage(switcher: switcher, refresh: _shown),
    );
  }
}
