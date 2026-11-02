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
