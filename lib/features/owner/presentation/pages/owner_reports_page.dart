import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../load_view.dart';

/// Owner: community reports as open/closed tickets. Applying or rejecting always closes the ticket.
class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  String _status = 'open';
  List<ReportTicket>? _tickets;
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
      final reports = await context.read<OwnerRepository>().reports(
        status: _status,
      );
      if (mounted) {
        setState(() {
          _tickets = reports;
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
    setState(() {
      _status = status;
      _tickets = null;
    });
    _load();
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
    _ => field,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final tickets = _tickets;
    return Scaffold(
      appBar: AppBar(title: Text(l.ownerReports)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: tickets == null
            ? null
            : ListView(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l.ownerReportOpen),
                          selected: _status == 'open',
                          onSelected: (_) => _switch('open'),
                        ),
                        ChoiceChip(
                          label: Text(l.ownerReportClosed),
                          selected: _status == 'closed',
                          onSelected: (_) => _switch('closed'),
                        ),
                      ],
                    ),
                  ),
                  if (tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.ownerReportEmpty,
                        textAlign: TextAlign.center,
                      ),
                    )
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
    return NotebookRow(
      mark: Icon(
        ticket.ready && ticket.status == 'open'
            ? Icons.rate_review_outlined
            : Icons.flag_outlined,
        size: 18,
        color: ticket.ready && ticket.status == 'open' ? nb.margin : nb.inkSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '$fieldLabel · ${l.ownerReportCount(ticket.count, ticket.threshold)}',
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          if (ticket.ready && ticket.status == 'open')
            Text(
              l.ownerReportReady,
              style: text.bodySmall?.copyWith(
                color: nb.margin,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${l.ownerReportCurrent}: ${ticket.current.label}',
            style: text.bodySmall,
          ),
          if (ticket.proposed case final proposed?)
            Text(
              '${l.ownerReportProposed}: ${proposed.label}',
              style: text.bodySmall,
            ),
          if (ticket.latestNote case final note? when note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${l.ownerReportLatestNote}: $note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: nb.inkSoft,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (ticket.status != 'open') ...[
            const SizedBox(height: 2),
            Text(
              verified == null ? status : '$status · $verified',
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          ],
          if (onApply != null && onReject != null)
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: Text(l.ownerReportReject),
                ),
                FilledButton(
                  onPressed: onApply,
                  child: Text(l.ownerReportApply),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
