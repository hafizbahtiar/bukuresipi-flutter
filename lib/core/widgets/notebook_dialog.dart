import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import 'notebook.dart';

/// info: one OK button. confirm: Cancel + a pandan yes. danger: Cancel + a red yes (deleting, signing out).
enum DialogTone { info, confirm, danger }

/// The app's one dialog: a slip of notebook paper (red margin line), a handwritten title, the message, then the
/// buttons. true = the positive button; false = Cancel, back or a tap outside. [content] goes under the message.
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
      backgroundColor: nb.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: nb.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: NotebookPage(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 2, 20, 20, 12),
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
              if (content != null) ...[const SizedBox(height: 12), content!],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (tone != DialogTone.info)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: nb.inkSoft),
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
      ),
    );
  }
}
