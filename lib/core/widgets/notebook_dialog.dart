import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import 'notebook.dart';

/// info: one OK button. confirm: Cancel + a pandan yes. danger: Cancel + a red yes (deleting, signing out).
enum DialogTone { info, confirm, danger }

/// The app's one dialog: a memo page (MEMO header, ruled lines, red margin), a handwritten title, the message,
/// then the buttons. true = the positive button; false = Cancel, back or a tap outside. [content] goes under the
/// message.
Future<bool> showNotebookDialog(
  BuildContext context, {
  String? title,
  required String message,
  DialogTone tone = DialogTone.confirm,
  String? confirmLabel,
  String? cancelLabel,
  Widget? content,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _NotebookDialog(
        title: title,
        message: message,
        tone: tone,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        content: content,
      ),
    ) ??
    false;

class _NotebookDialog extends StatelessWidget {
  const _NotebookDialog({
    required this.title,
    required this.message,
    required this.tone,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.content,
  });

  final String? title;
  final String message;
  final DialogTone tone;
  final String? confirmLabel;
  final String? cancelLabel;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final danger = tone == DialogTone.danger;
    final (icon, iconColor) = switch (tone) {
      DialogTone.info => (Icons.info_outline, nb.pandan),
      DialogTone.confirm => (Icons.help_outline, nb.pandan),
      DialogTone.danger => (Icons.warning_amber_rounded, nb.margin),
    };
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: _MemoPaper(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MemoHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                notebookGutter + 2,
                16,
                18,
                14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 22),
                      const SizedBox(width: 8),
                      if (title != null)
                        Expanded(
                          child: Text(
                            title!,
                            style: nb.hand.copyWith(fontSize: 28, height: 1.1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: text.bodyLarge),
                  if (content != null) ...[
                    const SizedBox(height: 12),
                    content!,
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (tone != DialogTone.info)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: nb.inkSoft,
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(cancelLabel ?? l.cancel),
                        ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: danger ? nb.margin : nb.pandan,
                          foregroundColor: nb.paper,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(confirmLabel ?? l.ok),
                      ),
                    ],
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

const _memoHeaderHeight = 54.0;
const _memoLineHeight = 30.0;

/// A page from a memo pad: square-ish paper, a MEMO band, pale-blue rules and the red margin line.
class _MemoPaper extends StatelessWidget {
  const _MemoPaper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      decoration: BoxDecoration(
        color: nb.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nb.line),
        boxShadow: [
          BoxShadow(
            color: nb.ink.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _MemoPainter(nb), child: child),
    );
  }
}

class _MemoHeader extends StatelessWidget {
  const _MemoHeader();

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    final now = DateTime.now();
    return Container(
      height: _memoHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: nb.ink.withValues(alpha: 0.14), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            'MEMO',
            style: text.labelLarge?.copyWith(
              color: nb.pandanDeep,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Text(
            '${m.formatMediumDate(now)}, ${now.year}',
            style: text.labelMedium?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _MemoPainter extends CustomPainter {
  const _MemoPainter(this.nb);

  final Notebook nb;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = nb.rule
      ..strokeWidth = 1;
    for (
      var y = _memoHeaderHeight + _memoLineHeight;
      y < size.height;
      y += _memoLineHeight
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = nb.margin.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      const Offset(notebookGutter - 8, _memoHeaderHeight),
      Offset(notebookGutter - 8, size.height),
      margin,
    );
  }

  @override
  bool shouldRepaint(_MemoPainter old) =>
      old.nb.paper != nb.paper ||
      old.nb.rule != nb.rule ||
      old.nb.margin != nb.margin;
}
