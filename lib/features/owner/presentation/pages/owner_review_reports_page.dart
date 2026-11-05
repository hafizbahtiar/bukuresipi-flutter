import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../../core/widgets/load_view.dart';

/// Owner moderation queue: reviews reported by the community; hide the text or keep it.
class OwnerReviewReportsPage extends StatefulWidget {
  const OwnerReviewReportsPage({super.key});

  @override
  State<OwnerReviewReportsPage> createState() => _OwnerReviewReportsPageState();
}

class _OwnerReviewReportsPageState extends State<OwnerReviewReportsPage> {
  List<ReviewReportGroup>? _groups;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await context.read<OwnerRepository>().reviewReports();
      if (mounted) {
        setState(() {
          _groups = groups;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(ReviewReportGroup group, bool hide) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<OwnerRepository>();
    final ok = await showNotebookDialog(
      context,
      message: hide ? l.ownerReviewHideConfirm : l.ownerReviewKeepConfirm,
      tone: hide ? DialogTone.danger : DialogTone.confirm,
      confirmLabel: hide ? l.ownerReviewHide : l.ownerReviewKeep,
    );
    if (!ok) return;
    try {
      await repo.resolveReviewReport(reviewId: group.reviewId, hide: hide);
      if (mounted) await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerReviewReports),
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: groups == null
            ? null
            : NotebookPage(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (groups.isEmpty)
                      NotebookRow(
                        minHeight: 110,
                        mark: Icon(
                          Icons.check_circle_outline,
                          color: nb.pandan,
                        ),
                        child: Text(l.ownerReviewReportsEmpty),
                      )
                    else
                      for (final group in groups)
                        _ReviewReportRow(
                          group: group,
                          fieldReasons: l.ownerReviewReportReasons(
                            group.reasons.join(', '),
                          ),
                          onHide: () => _resolve(group, true),
                          onKeep: () => _resolve(group, false),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReviewReportRow extends StatelessWidget {
  const _ReviewReportRow({
    required this.group,
    required this.fieldReasons,
    required this.onHide,
    required this.onKeep,
  });

  final ReviewReportGroup group;
  final String fieldReasons;
  final VoidCallback onHide;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    return NotebookRow(
      mark: Icon(Icons.flag_outlined, size: 18, color: nb.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.author,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                l.ownerReviewReportCount(group.count),
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
          Row(
            children: [
              for (var n = 1; n <= 5; n++)
                Icon(
                  n <= group.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: n <= group.stars ? nb.kunyit : nb.inkSoft,
                ),
              if (group.hidden)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l.ownerReviewHidden,
                    style: text.bodySmall?.copyWith(color: nb.margin),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(group.text, style: text.bodyMedium),
          Text(
            '$fieldReasons · ${m.formatShortDate(group.createdAt.toLocal())}',
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          if (group.latestNote case final note? when note.isNotEmpty)
            Text(
              note,
              style: text.bodySmall?.copyWith(
                color: nb.inkSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: onKeep, child: Text(l.ownerReviewKeep)),
              FilledButton(onPressed: onHide, child: Text(l.ownerReviewHide)),
            ],
          ),
        ],
      ),
    );
  }
}
