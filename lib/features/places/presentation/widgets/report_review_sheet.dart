import 'package:flutter/material.dart';

import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/review.dart';

/// Report a review with a reason and an optional note.
class ReportReviewSheet extends StatefulWidget {
  const ReportReviewSheet({super.key, required this.onSubmit});

  final Future<void> Function(ReviewReason reason, String? note) onSubmit;

  @override
  State<ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<ReportReviewSheet> {
  ReviewReason _reason = ReviewReason.spam;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        _reason,
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.reviewReportSent)));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(AppLocalizations l, ReviewReason reason) => switch (reason) {
    ReviewReason.spam => l.reviewReportSpam,
    ReviewReason.offensive => l.reviewReportOffensive,
    ReviewReason.wrongInfo => l.reviewReportWrong,
    ReviewReason.other => l.reviewReportOther,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
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
                    l.reviewReportTitle,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.reviewReportReason,
                    style: text.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  NotebookSegmented<ReviewReason>(
                    selected: _reason,
                    onChanged: (reason) => setState(() => _reason = reason),
                    segments: [
                      for (final reason in ReviewReason.values)
                        NotebookSegment(
                          value: reason,
                          label: _label(l, reason),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(labelText: l.reviewReportNote),
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
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l.reviewReport),
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
