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

/// Owner: community reports as open/closed tickets. Applying or rejecting always closes the ticket.
class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  String _status = 'open';
  // Both tabs are loaded together; switching is instant and does not flash the page.
  Map<String, List<ReportTicket>>? _reports;
  Object? _error;
  bool _loading = true;

  List<ReportTicket>? get _tickets => _reports?[_status];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<OwnerRepository>();
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        repo.reports(status: 'open'),
        repo.reports(status: 'closed'),
      ]);
      if (mounted) {
        setState(() {
          _reports = {'open': results[0], 'closed': results[1]};
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switch(String status) {
    if (status == _status) return;
    setState(() => _status = status);
  }

  Future<void> _resolve(ReportTicket ticket, bool apply) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<OwnerRepository>();
    final ok = await showNotebookDialog(
      context,
      message: apply ? l.ownerReportApplyConfirm : l.ownerReportRejectConfirm,
      tone: apply ? DialogTone.confirm : DialogTone.danger,
      confirmLabel: apply ? l.ownerReportApply : l.ownerReportReject,
    );
    if (!ok) return;
    try {
      await repo.resolveReport(
        targetType: ticket.targetType,
        targetId: ticket.targetId,
        field: ticket.field,
        apply: apply,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  String _fieldLabel(AppLocalizations l, String field) => switch (field) {
    'location' => l.reportFieldLocation,
    'label' => l.reportFieldLabel,
    'address' => l.reportFieldAddress,
    'city' => l.reportFieldCity,
    'state' => l.reportFieldState,
    'name' => l.reportFieldName,
    'cuisine' => l.reportFieldCuisine,
    'status' => l.reportFieldStatus,
    _ => field,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final tickets = _tickets;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.ownerReports)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: tickets == null
            ? null
            : NotebookPage(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        notebookGutter + 10,
                        8,
                        20,
                        12,
                      ),
                      child: Text(
                        l.ownerReportsHelp,
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                      ),
                    ),
                    NotebookRow(
                      mark: Icon(Icons.swap_horiz, size: 18, color: nb.inkSoft),
                      child: NotebookSegmented<String>(
                        selected: _status,
                        onChanged: _switch,
                        segments: [
                          NotebookSegment(
                            value: 'open',
                            label: l.ownerReportOpen,
                          ),
                          NotebookSegment(
                            value: 'closed',
                            label: l.ownerReportClosed,
                          ),
                        ],
                      ),
                    ),
                    if (tickets.isEmpty)
                      _Empty(status: _status)
                    else
                      for (final ticket in tickets)
                        _TicketRow(
                          ticket: ticket,
                          fieldLabel: _fieldLabel(l, ticket.field),
                          onApply: _status == 'open'
                              ? () => _resolve(ticket, true)
                              : null,
                          onReject: _status == 'open'
                              ? () => _resolve(ticket, false)
                              : null,
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final open = status == 'open';
    return NotebookRow(
      minHeight: 132,
      mark: Icon(
        open ? Icons.check_circle_outline : Icons.inventory_2_outlined,
        size: 22,
        color: open ? nb.pandan : nb.inkSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            open ? l.ownerReportEmpty : l.ownerReportEmptyClosed,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            open ? l.ownerReportEmptyHint : l.ownerReportEmptyClosedHint,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({
    required this.ticket,
    required this.fieldLabel,
    this.onApply,
    this.onReject,
  });

  final ReportTicket ticket;
  final String fieldLabel;
  final VoidCallback? onApply;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    final status = switch (ticket.status) {
      'applied' => l.ownerReportApplied,
      'rejected' => l.ownerReportRejected,
      _ => l.ownerReportOpen,
    };
    final verified = ticket.verifiedAt == null
        ? null
        : l.ownerReportVerifiedAt(
            m.formatShortDate(ticket.verifiedAt!.toLocal()),
          );
    final ready = ticket.ready && ticket.status == 'open';
    // A status report holds "closed" / "open": shown in words.
    String shown(ReportValue v) => switch ((ticket.field, v.value)) {
      ('status', 'closed') => l.branchClosed,
      ('status', 'open') => l.branchOpen,
      _ => v.label,
    };
    return NotebookRow(
      mark: Icon(
        ready ? Icons.rate_review_outlined : Icons.flag_outlined,
        size: 18,
        color: ready ? nb.margin : nb.inkSoft,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ticket.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: nb.mist,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    fieldLabel,
                    style: text.labelSmall?.copyWith(
                      color: nb.pandanDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                l.ownerReportCount(ticket.count, ticket.threshold),
                if (ready) l.ownerReportReady,
                if (ticket.status != 'open')
                  verified == null ? status : '$status · $verified',
              ].join(' · '),
              style: text.bodySmall?.copyWith(
                color: ready ? nb.margin : nb.inkSoft,
                fontWeight: ready ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 10),
            // Now -> suggested, side by side in one box: the change the owner applies.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: Border.all(color: nb.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Value(
                    label: l.ownerReportCurrent,
                    value: shown(ticket.current),
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                  if (ticket.proposed case final proposed?) ...[
                    Divider(height: 14, color: nb.line),
                    _Value(
                      label: l.ownerReportProposed,
                      value: shown(proposed),
                      style: text.bodyMedium?.copyWith(
                        color: nb.pandanDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (ticket.latestNote case final note? when note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '“$note”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: nb.inkSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (onApply != null && onReject != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onReject,
                      child: Text(l.ownerReportReject),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onApply,
                      child: Text(l.ownerReportApply),
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

/// One line of the now/suggested box: a fixed-width label, then the value (wraps under itself).
class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: text.labelMedium?.copyWith(
              color: Notebook.of(context).inkSoft,
            ),
          ),
        ),
        Expanded(child: Text(value, style: style)),
      ],
    );
  }
}
