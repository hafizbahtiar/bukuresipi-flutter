import 'package:flutter/material.dart';

import '../../../core/widgets/notebook.dart';
import '../../../core/widgets/pill_switch.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../receipts/presentation/pages/calories_page.dart';
import '../../receipts/presentation/pages/receipts_page.dart';

/// The Receipts tab: one notebook page, like a recipe's. Its Receipts | Calories switch is pinned under the title
/// and only what is under it changes; both sides stay loaded, so a switch is instant (and reloads that side quietly).
class ReceiptsTab extends StatefulWidget {
  const ReceiptsTab({super.key});

  @override
  State<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<ReceiptsTab> {
  bool _calories = false;
  final _receipts = GlobalKey<ReceiptsSectionState>();
  final _kcal = GlobalKey<CaloriesSectionState>();

  Future<void> _refresh() async => _calories
      ? _kcal.currentState?.refresh()
      : _receipts.currentState?.refresh();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(_calories ? l.navCalories : l.receiptsTitle),
      ),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: NotebookPinnedBar(
                  height: MediaQuery.textScalerOf(context).scale(40) + 16,
                  child: PillSwitch<bool>(
                    key: const ValueKey('receipts-switch'),
                    expand: true,
                    value: _calories,
                    onChanged: (v) {
                      if (v == _calories) return;
                      setState(() => _calories = v);
                      _refresh(); // a receipt may have been added meanwhile
                    },
                    options: [
                      (
                        false,
                        PillLabel(Icons.receipt_long_outlined, l.navReceipts),
                        null,
                      ),
                      (
                        true,
                        PillLabel(
                          Icons.local_fire_department_outlined,
                          l.navCalories,
                        ),
                        null,
                      ),
                    ],
                  ),
                ),
              ),
              SliverVisibility(
                visible: !_calories,
                maintainState: true,
                sliver: ReceiptsSection(key: _receipts),
              ),
              SliverVisibility(
                visible: _calories,
                maintainState: true,
                sliver: CaloriesSection(key: _kcal),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
