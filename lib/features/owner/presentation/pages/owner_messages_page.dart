import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../widgets/message_sheet.dart';

/// Owner > Send notifications: a message to everyone or one user (also Users > a user), and what was sent, with how
/// many phones its push reached so far (read again every few seconds while one is still pushing). A tap opens one in a
/// sheet: its photo, whole text, kind and Delete (the count as it was when opened).
class OwnerMessagesPage extends StatefulWidget {
  const OwnerMessagesPage({super.key});

  @override
  State<OwnerMessagesPage> createState() => _OwnerMessagesPageState();
}

class _OwnerMessagesPageState extends State<OwnerMessagesPage> {
  List<SentMessage>? _sent;
  Object? _error;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    _poll?.cancel();
    if (!quiet) setState(() => _loading = true);
    try {
      final s = await context.read<OwnerRepository>().sentMessages();
      if (!mounted) return;
      setState(() {
        _sent = s;
        _error = null;
      });
      if (s.any((m) => m.pending)) {
        _poll = Timer(const Duration(seconds: 5), () => _load(quiet: true));
      }
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _new() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showBaseSheet<bool>(
      context,
      builder: (_) => const MessageSheet(),
    );
    if (sent != true || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l.ownerMessageSent)));
    await _load();
  }

  Future<void> _delete(SentMessage m) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showBaseDialog(
      context,
      message: l.ownerMessageDeleteAsk(m.title),
      tone: DialogTone.danger,
      confirmLabel: l.delete,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<OwnerRepository>().deleteMessage(m.id);
      messenger.showSnackBar(SnackBar(content: Text(l.ownerMessageDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
    await _load(quiet: true);
  }

  String _when(SentMessage m) =>
      '${MaterialLocalizations.of(context).formatMediumDate(m.createdAt)}, ${formatTime(context, m.createdAt)}';

  List<TileTag> _tags(SentMessage m, AppLocalizations l) => [
    TileTag(m.to ?? l.ownerMessageEveryone),
    if (m.kind == 'update') TileTag(l.msgTpl1Label),
    if (m.pending)
      TileTag(l.ownerMessagePending, tone: TagTone.warn)
    else if (m.pushTotal == 0)
      TileTag(l.ownerMessageInboxOnly)
    else
      TileTag(
        l.ownerMessagePhones(m.pushSent, m.pushTotal),
        tone: TagTone.good,
      ),
  ];

  Future<void> _open(SentMessage m) async {
    final delete = await showBaseSheet<bool>(
      context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        final nb = Notebook.of(context);
        final text = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spaceS,
            children: [
              if (m.image case final url?)
                ClipRRect(
                  key: const ValueKey('sent-image'),
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Text(
                m.title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(_when(m), style: TextStyle(color: nb.inkSoft)),
              Wrap(
                spacing: spaceXs,
                runSpacing: spaceXs,
                children: [for (final t in _tags(m, l)) TagChip(t)],
              ),
              SelectableText(m.body, style: TextStyle(color: nb.ink)),
              PanelActions(
                children: [
                  TextButton.icon(
                    key: const ValueKey('sent-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.delete),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (delete == true && mounted) await _delete(m);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final sent = _sent;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.inboxTitle),
        actions: [
          IconButton(
            key: const ValueKey('messages-new'),
            tooltip: l.ownerMessageNew,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _new,
          ),
        ],
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: sent == null
            ? null
            : RefreshIndicator(
                onRefresh: _load,
                child: WidePage(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: spaceS),
                    children: [
                      if (sent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(spaceL),
                          child: Text(
                            l.ownerMessagesNone,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: nb.inkSoft),
                          ),
                        ),
                      for (final (i, m) in sent.indexed)
                        BaseTile(
                          key: ValueKey('sent-$i'),
                          dense: true,
                          title: m.title,
                          subtitle: _when(m),
                          footer: Text(
                            m.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: nb.ink),
                          ),
                          onTap: () => _open(m),
                          actions: [
                            MenuAction(
                              icon: Icons.delete_outline,
                              label: l.delete,
                              danger: true,
                              onTap: () => _delete(m),
                            ),
                          ],
                          tags: _tags(m, l),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
