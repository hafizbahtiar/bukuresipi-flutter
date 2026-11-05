import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import 'notebook.dart';

/// info: one OK button. confirm: Cancel + a pandan yes. danger: Cancel + a red yes (deleting, signing out).
/// Buttons sit in a row when they fit, else stack (the answer on top); see _Buttons.
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
    final heading = title == null
        ? null
        : Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title!,
                  style: nb.hand.copyWith(fontSize: 28, height: 1.1),
                ),
              ),
            ],
          );
    // No title: the icon sits beside the message instead of alone on its own line.
    final body = title == null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: text.bodyLarge)),
            ],
          )
        : Text(message, style: text.bodyLarge);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      // A memo, not a banner: on a tablet or a phone on its side it stays memo-sized.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _MemoPaper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _MemoHeader(),
              // Long text, big font or the keyboard up: the words scroll, the buttons stay in reach.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    notebookGutter + 2,
                    16,
                    18,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (heading != null) ...[
                        heading,
                        const SizedBox(height: 10),
                      ],
                      body,
                      if (content != null) ...[
                        const SizedBox(height: 12),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  notebookGutter + 2,
                  18,
                  18,
                  14,
                ),
                child: _Buttons(
                  cancel: tone == DialogTone.info
                      ? null
                      : cancelLabel ?? l.cancel,
                  confirm: confirmLabel ?? l.ok,
                  danger: danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side by side when both labels fit on one line (Cancel left, the answer right, as Android does); otherwise
/// stacked full width with the answer on top, where the thumb lands first, and Cancel under it.
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.cancel,
    required this.confirm,
    required this.danger,
  });

  final String? cancel;
  final String confirm;
  final bool danger;

  static const _gap = 8.0;
  static const _pad = 20.0; // each side of a label

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    double width(String label) =>
        (TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width +
        2 * _pad;
    const padding = EdgeInsets.symmetric(horizontal: _pad);
    final yes = FilledButton(
      key: const ValueKey('dialog-confirm'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: padding,
        backgroundColor: danger ? nb.margin : nb.pandan,
        foregroundColor: nb.paper,
      ),
      onPressed: () => Navigator.pop(context, true),
      child: Text(confirm, textAlign: TextAlign.center),
    );
    final no = cancel == null
        ? null
        : TextButton(
            key: const ValueKey('dialog-cancel'),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              padding: padding,
              foregroundColor: nb.inkSoft,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancel!, textAlign: TextAlign.center),
          );
    return LayoutBuilder(
      builder: (context, box) {
        final need =
            width(confirm) + (cancel == null ? 0 : _gap + width(cancel!));
        if (need <= box.maxWidth) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (no != null) ...[no, const SizedBox(width: _gap)],
              yes,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            yes,
            if (no != null) ...[const SizedBox(height: 4), no],
          ],
        );
      },
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
      // At least the band the painter draws; taller with big text rather than clipping it.
      constraints: const BoxConstraints(minHeight: _memoHeaderHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${m.formatMediumDate(now)}, ${now.year}',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(color: nb.inkSoft),
            ),
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
