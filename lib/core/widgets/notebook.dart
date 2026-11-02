import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Left gutter (the margin) of a notebook page: marks sit in it, text starts after the red line.
const notebookGutter = 56.0;

/// A page with the red margin line down the left. Rows draw their own blue rules, so they always line up.
class NotebookPage extends StatelessWidget {
  const NotebookPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Stack(
      children: [
        Positioned(
          left: notebookGutter - 8,
          top: 0,
          bottom: 0,
          child: ExcludeSemantics(
            child: Container(
              width: 1.5,
              color: nb.margin.withValues(alpha: 0.55),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// One line of the notebook: a [mark] in the margin, the text on the line, a pale-blue rule under it.
class NotebookRow extends StatelessWidget {
  const NotebookRow({
    super.key,
    this.mark,
    required this.child,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
  });

  final Widget? mark;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: nb.rule)),
        ),
        padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: notebookGutter - 8,
              child: Center(child: mark),
            ),
            const SizedBox(width: 18),
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The page's title, handwritten, as on a notebook cover.
class NotebookTitle extends StatelessWidget {
  const NotebookTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Notebook.of(context).hand.copyWith(fontSize: 34, height: 1),
  );
}

/// Margin mark: a filled pandan dot = on the map; a hollow kunyit ring = no pin yet.
class PinMark extends StatelessWidget {
  const PinMark({super.key, required this.pinned});

  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pinned ? nb.pandan : null,
        border: pinned ? null : Border.all(color: nb.kunyit, width: 2.5),
      ),
    );
  }
}

/// A bottom sheet as a notebook page: paper, the red margin line, ruled rows inside.
Future<T?> showNotebookSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final nb = Notebook.of(context);
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: nb.paper,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      side: BorderSide(color: nb.line),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: NotebookPage(child: builder(context)),
      ),
    ),
  );
}

/// One button of an [ActionDock]. No [onPressed] = shown, but off.
class DockAction {
  const DockAction({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.danger = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool danger;
  final bool busy;
}

/// A page's actions on a slip of paper floating at the bottom, always in reach. Use as the Scaffold's
/// bottomNavigationBar with `extendBody: true`, and pad the page's list by [ActionDock.clearance].
class ActionDock extends StatelessWidget {
  const ActionDock({super.key, required this.actions});

  final List<DockAction> actions;

  static const clearance = 104.0;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    // A Scaffold's bottom bar stays under the keyboard: lift the dock above it.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: nb.paper,
          elevation: 3,
          shadowColor: nb.ink.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: nb.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              for (final a in actions) Expanded(child: _DockButton(action: a)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.action});

  final DockAction action;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final a = action;
    final on = a.onPressed != null && !a.busy;
    final color = !on
        ? nb.inkSoft.withValues(alpha: 0.45)
        : a.danger
        ? nb.margin
        : nb.pandanDeep;
    return Tooltip(
      message: a.tooltip ?? a.label,
      child: InkWell(
        onTap: on ? a.onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 24,
                child: a.busy
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: nb.pandan,
                        ),
                      )
                    : Icon(a.icon, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                a.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading on the page, after the margin line.
class NotebookHeading extends StatelessWidget {
  const NotebookHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 28, 20, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
