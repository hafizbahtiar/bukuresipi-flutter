import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';

/// info: one OK button. confirm: Cancel + a pandan yes. danger: Cancel + a red yes (deleting, signing out).
/// Buttons sit in a row when they fit, else stack (the answer on top); see _Buttons.
enum DialogTone { info, confirm, danger }

/// A standard dialog: a title, a message, Cancel and the [tone]'s button.
/// true = the positive button; false = Cancel, back or a tap outside.
Future<bool> showBaseDialog(
  BuildContext context, {
  String? title,
  required String message,
  DialogTone tone = DialogTone.confirm,
  String? confirmLabel,
  String? cancelLabel,
  Widget? content,
}) async {
  final l = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  final nb = Notebook.of(context);
  final danger = tone == DialogTone.danger;
  final accent = danger ? scheme.error : nb.pandan;
  // The theme's FilledButton is a full-width bar (forms): in a dialog it is a normal-size button, so the answer
  // and Cancel read as a pair, the answer on the right.
  const size = Size(64, 40);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          // A phone on its side (or big text) leaves little height: the words scroll instead of overflowing.
          scrollable: true,
          icon: Icon(switch (tone) {
            DialogTone.info => Icons.info_outline,
            DialogTone.confirm => Icons.help_outline,
            DialogTone.danger => Icons.warning_amber_rounded,
          }, color: accent),
          title: title == null ? null : Text(title, style: text.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                textAlign: title == null ? TextAlign.center : TextAlign.start,
                style: (title == null ? text.bodyLarge : text.bodyMedium)
                    ?.copyWith(color: title == null ? nb.ink : nb.inkSoft),
              ),
              ?content,
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            spaceL,
            0,
            spaceL,
            spaceL - spaceXs,
          ),
          actions: [
            if (tone != DialogTone.info)
              TextButton(
                key: const ValueKey('dialog-cancel'),
                style: TextButton.styleFrom(
                  minimumSize: size,
                  foregroundColor: nb.inkSoft,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelLabel ?? l.cancel),
              ),
            FilledButton(
              key: const ValueKey('dialog-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: size,
                padding: const EdgeInsets.symmetric(horizontal: spaceL),
                textStyle: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: accent,
                foregroundColor: danger ? scheme.onError : Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel ?? l.ok),
            ),
          ],
        ),
      ) ??
      false;
}
