import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/family.dart';
import '../ask.dart';
import '../family_controller.dart';

/// Profile > Family: start one, or see the members, invite by link (owner) and leave.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<FamilyController>().load(),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Every action reports its own failure; the page stays as it was.
  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final family = context.read<FamilyController>();
    final name = await askText(
      context,
      title: l.familyStart,
      message: l.familyNameAsk,
      hint: l.familyNameHint,
    );
    if (name == null || !mounted) return;
    if (!validName(name)) return _snack(l.errName);
    await _run(() async {
      if (await withName(context, () => family.create(name)) && mounted) {
        await _invite();
      }
    });
  }

  Future<void> _rename(Family f) async {
    final l = AppLocalizations.of(context);
    final family = context.read<FamilyController>();
    final name = await askText(
      context,
      title: l.familyRename,
      message: l.familyNameAsk,
      initial: f.name,
    );
    if (name == null) return;
    if (!validName(name)) return _snack(l.errName);
    await _run(() => family.rename(name));
  }

  /// A new link (stops the old one), then where to send it.
  Future<void> _invite() async {
    final l = AppLocalizations.of(context);
    final link = await context.read<FamilyController>().invite();
    if (!mounted) return;
    final message = l.familyInviteText(link.url);
    final until = l.familyLinkUntil(
      DateFormat.yMMMd(l.localeName).format(link.expiresAt),
    );
    await showNotebookSheet<void>(
      context,
      builder: (sheet) {
        final nb = Notebook.of(sheet);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            NotebookRow(
              child: Text(
                l.familyInvite,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            NotebookRow(
              child: Text(until, style: TextStyle(color: nb.inkSoft)),
            ),
            NotebookRow(
              mark: Icon(Icons.chat_outlined, size: 20, color: nb.pandan),
              onTap: () => openLink(
                sheet,
                'https://wa.me/?text=${Uri.encodeComponent(message)}',
                failed: l.openFailed,
              ),
              child: Text(l.familyShareWhatsApp),
            ),
            NotebookRow(
              mark: Icon(Icons.copy, size: 20, color: nb.inkSoft),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (sheet.mounted) Navigator.of(sheet).pop();
                _snack(l.familyLinkCopied);
              },
              child: Text(l.familyCopyLink),
            ),
          ],
        );
      },
    );
  }

  Future<void> _memberMenu(Family f, FamilyMember m) async {
    final l = AppLocalizations.of(context);
    final family = context.read<FamilyController>();
    final choice = await showNotebookSheet<String>(
      context,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          NotebookRow(
            child: Text(
              m.name ?? '?',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          NotebookRow(
            onTap: () => Navigator.of(sheet).pop('owner'),
            child: Text(l.familyMakeOwner),
          ),
          NotebookRow(
            onTap: () => Navigator.of(sheet).pop('remove'),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'owner') return _run(() => family.handOver(m.id));
    if (await showNotebookDialog(
      context,
      message: l.familyRemoveConfirm(m.name ?? '?'),
      tone: DialogTone.danger,
      confirmLabel: l.remove,
    )) {
      await _run(() => family.removeMember(m.id));
    }
  }

  /// "Created by Ali · 5 Nov 2026", "Created by you · …", or only the date when the creator's account is gone.
  String? _created(AppLocalizations l, Family f) {
    final at = f.createdAt;
    final date = at == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(at);
    final who = f.creatorIsMe ? l.familyCreatedByYou : f.createdBy;
    if (who != null) {
      return date == null
          ? l.familyCreatedBy(who)
          : '${l.familyCreatedBy(who)} · $date';
    }
    return date == null ? null : l.familyCreatedOn(date);
  }

  Future<void> _leave(Family f) async {
    final l = AppLocalizations.of(context);
    final family = context.read<FamilyController>();
    if (await showNotebookDialog(
      context,
      message: l.familyLeaveConfirm(f.name),
      tone: DialogTone.danger,
      confirmLabel: l.familyLeave,
    )) {
      await _run(family.leave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final controller = context.watch<FamilyController>();
    final f = controller.family;
    final List<Widget> rows;
    if (!controller.loaded) {
      rows = const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    } else if (f == null) {
      rows = [
        NotebookRow(minHeight: 96, child: Text(l.familyIntro)),
        NotebookRow(
          mark: Icon(Icons.group_add_outlined, size: 20, color: nb.pandan),
          onTap: _busy ? null : _start,
          child: Text(
            l.familyStart,
            style: TextStyle(color: nb.pandanDeep, fontWeight: FontWeight.w600),
          ),
        ),
        NotebookRow(
          child: Text(l.familyGotLink, style: TextStyle(color: nb.inkSoft)),
        ),
      ];
    } else {
      final until = f.inviteExpiresAt;
      rows = [
        NotebookRow(
          onTap: f.isOwner && !_busy ? () => _rename(f) : null,
          trailing: f.isOwner
              ? Icon(Icons.edit_outlined, size: 18, color: nb.inkSoft)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.name,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_created(l, f) case final line?)
                Text(line, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
            ],
          ),
        ),
        for (final m in f.members)
          NotebookRow(
            mark: Icon(
              m.isOwner ? Icons.star_outline : Icons.person_outline,
              size: 20,
              color: nb.inkSoft,
            ),
            onTap: f.isOwner && !m.isMe && !_busy
                ? () => _memberMenu(f, m)
                : null,
            trailing: f.isOwner && !m.isMe
                ? Icon(Icons.more_vert, size: 18, color: nb.inkSoft)
                : null,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: m.name ?? '?'),
                  if (m.isOwner || m.isMe)
                    TextSpan(
                      text:
                          '  ${[if (m.isOwner) l.familyOwner, if (m.isMe) l.familyYou].join(' · ')}',
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                ],
              ),
            ),
          ),
        if (f.isOwner) ...[
          NotebookRow(
            mark: Icon(Icons.share_outlined, size: 20, color: nb.pandan),
            onTap: _busy ? null : () => _run(_invite),
            child: Text(
              l.familyInvite,
              style: TextStyle(
                color: nb.pandanDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (until != null)
            NotebookRow(
              trailing: TextButton(
                onPressed: _busy ? null : () => _run(controller.stopInvite),
                child: Text(l.familyStopLink),
              ),
              child: Text(
                l.familyLinkUntil(DateFormat.yMMMd(l.localeName).format(until)),
                style: TextStyle(color: nb.inkSoft),
              ),
            ),
        ],
        NotebookRow(
          mark: Icon(Icons.logout, size: 20, color: nb.margin),
          onTap: _busy ? null : () => _leave(f),
          child: Text(l.familyLeave, style: TextStyle(color: nb.margin)),
        ),
      ];
    }
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.familyTitle)),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: rows,
          ),
        ),
      ),
    );
  }
}
