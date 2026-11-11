import 'package:flutter/material.dart';

import '../../../core/widgets/notebook.dart';
import '../../../core/widgets/pill_switch.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../receipts/presentation/pages/calories_page.dart';
import '../../receipts/presentation/pages/receipts_page.dart';

/// The Receipts tab: one notebook page, like a recipe's. Its Receipts | Calories switch stays under the title over
/// two pages, swiped or picked; each side stays loaded once seen, so a switch is instant (and reloads that side quietly).
class ReceiptsTab extends StatefulWidget {
  const ReceiptsTab({super.key});

  @override
  State<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<ReceiptsTab> {
  bool _calories = false;
  final _receipts = GlobalKey<ReceiptsSectionState>();
  final _kcal = GlobalKey<CaloriesSectionState>();
  // Receipts | Calories as pages: swiped, or driven by the pill (it follows the swipe).
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _refresh() async => _calories
      ? _kcal.currentState?.refresh()
      : _receipts.currentState?.refresh();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget page(Widget section, Future<void> Function() refresh) => _KeepAlive(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            section,
            SliverToBoxAdapter(child: SizedBox(height: navRoom(context))),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(_calories ? l.navCalories : l.receiptsTitle),
      ),
      body: NotebookPage(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 8),
              child: PillSwitch<bool>(
                key: const ValueKey('receipts-switch'),
                expand: true,
                value: _calories,
                onChanged: (
                  _,
                ) {}, // with pages, onPageChanged reports the change
                pages: _pages,
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
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  setState(() => _calories = i == 1);
                  _refresh(); // a receipt may have been added meanwhile
                },
                children: [
                  page(
                    ReceiptsSection(key: _receipts),
                    () async => _receipts.currentState?.refresh(),
                  ),
                  page(
                    CaloriesSection(key: _kcal),
                    () async => _kcal.currentState?.refresh(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a page built while the other one shows: both sides stay loaded, so a switch is instant.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
