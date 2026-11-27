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
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../widgets/message_sheet.dart';

/// Owner > Send notifications: a message to everyone (one to a single user: Users > a user), and what was sent, with
/// how many phones its push reached so far.
class OwnerMessagesPage extends StatefulWidget {
  const OwnerMessagesPage({super.key});

  @override
  State<OwnerMessagesPage> createState() => _OwnerMessagesPageState();
}

class _OwnerMessagesPageState extends State<OwnerMessagesPage> {
  List<SentMessage>? _sent;
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
      final s = await context.read<OwnerRepository>().sentMessages();
      if (mounted) {
        setState(() {
          _sent = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final loc = MaterialLocalizations.of(context);
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
                          subtitle:
                              '${loc.formatMediumDate(m.createdAt)}, ${formatTime(context, m.createdAt)}',
                          // The whole text: the tile's subtitle stops at 2 lines.
                          footer: Text(m.body, style: TextStyle(color: nb.ink)),
                          tags: [
                            TileTag(m.to ?? l.ownerMessageEveryone),
                            if (m.pending)
                              TileTag(l.ownerMessagePending, tone: TagTone.warn)
                            else if (m.pushTotal == 0)
                              TileTag(l.ownerMessageInboxOnly)
                            else
                              TileTag(
                                l.ownerMessagePhones(m.pushSent, m.pushTotal),
                                tone: TagTone.good,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
