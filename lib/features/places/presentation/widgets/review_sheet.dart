import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';

/// Write or edit the optional text attached to the caller's rating.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.initialStars,
    required this.initialText,
    required this.onSave,
    this.onRemove,
  });

  final int initialStars;
  final String? initialText;
  final Future<void> Function(int stars, String text) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late int _stars = widget.initialStars.clamp(1, 5);
  late final _text = TextEditingController(text: widget.initialText ?? '');
  bool _saving = false;
  bool _removing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await widget.onSave(_stars, _text.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.reviewSaved)));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showNotebookDialog(
      context,
      message: l.reviewRemoveConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.reviewRemove,
    );
    if (!ok || !mounted) return;
    setState(() => _removing = true);
    try {
      await widget.onRemove!();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.reviewRemoved)));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final canSave = !_saving && !_removing && _text.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.initialText == null ? l.reviewWrite : l.reviewEdit,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        IconButton(
                          key: ValueKey('review-star-$n'),
                          onPressed: _saving || _removing
                              ? null
                              : () => setState(() => _stars = n),
                          icon: Icon(
                            n <= _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: n <= _stars ? nb.kunyit : nb.inkSoft,
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: l.reviewTextHint),
                  ),
                  if (widget.onRemove != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _saving || _removing ? null : _remove,
                        child: Text(l.reviewRemove),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving || _removing
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: _saving || _removing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l.save),
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
