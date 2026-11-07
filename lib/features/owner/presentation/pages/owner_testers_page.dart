import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// The website's Android tester signups. "Copy all" puts the emails on the clipboard, one per line, for the Play
/// Console closed test. Google emails nobody on that list, so after adding them the owner presses Done: we send the
/// opt-in link, and each row then shows whether it arrived (Resend's status).
class OwnerTestersPage extends StatefulWidget {
  const OwnerTestersPage({super.key});

  @override
  State<OwnerTestersPage> createState() => _OwnerTestersPageState();
}

class _OwnerTestersPageState extends State<OwnerTestersPage> {
  List<Tester>? _testers;
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
      final testers = await context.read<OwnerRepository>().testers();
      if (mounted) {
        setState(() {
          _testers = testers;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(List<Tester> testers) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: testers.map((t) => t.email).join('\n')),
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l.ownerTestersCopied(testers.length))),
    );
  }

  Future<void> _invite(Tester t) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final owner = context.read<OwnerRepository>();
    final sure = await showNotebookDialog(
      context,
      message: t.invitedAt == null
          ? l.ownerTesterInviteConfirm(t.email)
          : l.ownerTesterResendConfirm(t.email),
      confirmLabel: t.invitedAt == null
          ? l.ownerTesterDone
          : l.ownerTesterResend,
    );
    if (!sure) return;
    try {
      await owner.inviteTester(t.email);
      messenger.showSnackBar(SnackBar(content: Text(l.ownerTesterInvited)));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    final testers = _testers;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerTesters),
        actions: [
          if (testers != null && testers.isNotEmpty)
            IconButton(
              tooltip: l.ownerTestersCopy,
              icon: const Icon(Icons.copy_all),
              onPressed: () => _copy(testers),
            ),
        ],
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: testers == null
            ? null
            : NotebookPage(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (testers.isEmpty)
                        NotebookRow(
                          minHeight: 110,
                          mark: Icon(Icons.people_outline, color: nb.inkSoft),
                          child: Text(l.ownerTestersEmpty),
                        ),
                      for (final t in testers)
                        NotebookRow(
                          onTap: t.invitedAt == null ? null : () => _invite(t),
                          trailing: t.invitedAt == null
                              ? FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                  ),
                                  onPressed: () => _invite(t),
                                  child: Text(l.ownerTesterDone),
                                )
                              : _EmailStatus(status: t.emailStatus),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(t.email),
                              Text(
                                [
                                  m.formatShortDate(t.joinedAt.toLocal()),
                                  t.lang.toUpperCase(),
                                  if (t.invitedAt case final at?)
                                    l.ownerTesterInvitedOn(
                                      m.formatShortDate(at.toLocal()),
                                    ),
                                ].join(' · '),
                                style: text.bodySmall?.copyWith(
                                  color: nb.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Where the invite email got to, as Resend saw it. Delivered = their mail server took it (not that they read it).
class _EmailStatus extends StatelessWidget {
  const _EmailStatus({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final (icon, label, color) = switch (status) {
      'delivered' => (
        Icons.mark_email_read_outlined,
        l.emailDelivered,
        nb.pandanDeep,
      ),
      'opened' ||
      'clicked' => (Icons.drafts_outlined, l.emailOpened, nb.pandanDeep),
      'delivery_delayed' => (Icons.schedule, l.emailDelayed, nb.kunyit),
      'bounced' => (Icons.error_outline, l.emailBounced, nb.margin),
      'complained' => (Icons.report_outlined, l.emailComplained, nb.margin),
      'sent' => (Icons.outgoing_mail, l.emailSent, nb.inkSoft),
      _ => (Icons.help_outline, l.emailUnknown, nb.inkSoft),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
