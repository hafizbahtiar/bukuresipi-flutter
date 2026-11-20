import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';
import 'sheets.dart';

/// One item of a [MoreMenu]. No [onTap] = shown, but off. [danger] = red (remove, hide).
class MenuAction {
  const MenuAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
}

/// The app bar's ⋮ button: a page's actions in a popup menu, in the order given; a line sets the danger items
/// (remove, hide) apart at the end. Nothing to show = no button.
class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, required this.actions});

  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final nb = Notebook.of(context);
    return PopupMenuButton<int>(
      key: const ValueKey('more-menu'),
      icon: const Icon(Icons.more_vert),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      color: nb.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: nb.line),
      ),
      position: PopupMenuPosition.under,
      onSelected: (i) => actions[i].onTap?.call(),
      itemBuilder: (context) => [
        for (final (i, a) in actions.indexed) ...[
          if (a.danger && i > 0 && !actions[i - 1].danger)
            const PopupMenuDivider(),
          PopupMenuItem(
            value: i,
            enabled: a.onTap != null,
            child: Row(
              children: [
                Icon(
                  a.icon,
                  size: 20,
                  color: a.danger ? scheme.error : nb.inkSoft,
                ),
                const SizedBox(width: spaceM),
                Flexible(
                  child: Text(
                    a.label,
                    style: a.danger ? TextStyle(color: scheme.error) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// [actions] as a bottom sheet, [title] on top: a tile's long-press menu and its ⋮ button. A danger action is
/// red and comes last, after a divider.
Future<void> showActionSheet(
  BuildContext context, {
  String? title,
  required List<MenuAction> actions,
}) {
  final nb = Notebook.of(context);
  return showBaseSheet<void>(
    context,
    builder: (sheet) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
          for (final (i, a) in actions.indexed) ...[
            if (a.danger && i > 0 && !actions[i - 1].danger)
              const Divider(height: spaceS),
            ListTile(
              leading: Icon(a.icon, color: a.danger ? nb.margin : null),
              title: Text(
                a.label,
                style: a.danger ? TextStyle(color: nb.margin) : null,
              ),
              enabled: a.onTap != null,
              onTap: () {
                Navigator.pop(sheet);
                a.onTap?.call();
              },
            ),
          ],
        ],
      ),
    ),
  );
}
