import 'package:flutter/material.dart';

import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// The ban form: a reason (the user sees it) and how long. Pops `(days, reason)`; days null = for good.
class BanSheet extends StatefulWidget {
  const BanSheet({super.key, required this.email});

  final String email;

  @override
  State<BanSheet> createState() => _BanSheetState();
}

class _BanSheetState extends State<BanSheet> {
  final _reason = TextEditingController();
  int? _days = 7;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Form(
      title: l.ownerBanTitle(widget.email),
      reason: _reason,
      reasonLabel: l.ownerBanReason,
      onChanged: () => setState(() {}),
      danger: false,
      confirmKey: const ValueKey('ban-confirm'),
      confirmLabel: l.ownerBanConfirm,
      onConfirm: () =>
          Navigator.pop(context, (days: _days, reason: _reason.text.trim())),
      children: [
        Text(l.ownerBanFor, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in const [1, 7, 30, null])
              ChoiceChip(
                key: ValueKey('ban-days-${d ?? 'forever'}'),
                label: Text(d == null ? l.ownerBanForGood : l.ownerBanDays(d)),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
      ],
    );
  }
}

/// The delete form: a reason (kept in the log; a preset fills it) and whether the email may sign up again.
/// Pops `(reason, banEmail)`. [email] is what the title names: one address, or "3 accounts" for a bulk delete.
class DeleteUserSheet extends StatefulWidget {
  const DeleteUserSheet({super.key, required this.email});

  final String email;

  @override
  State<DeleteUserSheet> createState() => _DeleteUserSheetState();
}

class _DeleteUserSheetState extends State<DeleteUserSheet> {
  final _reason = TextEditingController();
  bool _banEmail = true;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Form(
      title: l.ownerDeleteTitle(widget.email),
      reason: _reason,
      presets: [
        l.ownerReasonInactive,
        l.ownerReasonTester,
        l.ownerReasonSpam,
        l.ownerReasonAsked,
      ],
      reasonLabel: l.ownerDeleteWhy,
      onChanged: () => setState(() {}),
      danger: true,
      confirmKey: const ValueKey('delete-confirm'),
      confirmLabel: l.ownerDeleteConfirm,
      onConfirm: () => Navigator.pop(context, (
        reason: _reason.text.trim(),
        banEmail: _banEmail,
      )),
      children: [
        CheckboxListTile(
          key: const ValueKey('delete-ban-email'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _banEmail,
          onChanged: (v) => setState(() => _banEmail = v ?? false),
          title: Text(l.ownerDeleteBanEmail),
        ),
        Text(
          l.ownerDeleteWarning,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}

/// Shared layout: title, reason field (3+ characters, as the API), the form's own rows, Cancel + confirm.
class _Form extends StatelessWidget {
  const _Form({
    required this.title,
    required this.reason,
    required this.reasonLabel,
    required this.onChanged,
    required this.danger,
    required this.confirmKey,
    required this.confirmLabel,
    required this.onConfirm,
    required this.children,
    this.presets = const [],
  });

  final String title;

  /// Tap-to-fill reasons, shown above the field; with presets the keyboard waits for a tap on the field.
  final List<String> presets;
  final TextEditingController reason;
  final String reasonLabel;
  final VoidCallback onChanged;
  final bool danger;
  final Key confirmKey;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ready = reason.text.trim().length >= 3;
    // The keyboard's room sits below everything: the sheet rises above the keyboard, the buttons stay in sight,
    // and on a small phone the form between the title and the buttons scrolls instead of running under it.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (presets.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final (i, preset) in presets.indexed)
                          ChoiceChip(
                            key: ValueKey('delete-reason-$i'),
                            label: Text(preset),
                            selected: reason.text.trim() == preset,
                            onSelected: (_) {
                              reason.text = preset;
                              onChanged();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    key: const ValueKey('action-reason'),
                    controller: reason,
                    autofocus: presets.isEmpty,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(labelText: reasonLabel),
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
          // Always in sight, just above the keyboard: only the form above scrolls.
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(material.cancelButtonLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: confirmKey,
                    style: danger
                        ? FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          )
                        : null,
                    onPressed: ready ? onConfirm : null,
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
