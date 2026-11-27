import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner_repository.dart';

/// The owner's message: a title and text, in the inbox and pushed to the phones. To one user ([toId], named by
/// [toEmail]) or, opened without one, to everyone or a user picked on the To row. Sends it itself; pops true once sent.
class MessageSheet extends StatefulWidget {
  const MessageSheet({super.key, this.toId, this.toEmail});

  final String? toId;
  final String? toEmail;

  @override
  State<MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<MessageSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late ({String? id, String? email}) _to = (
    id: widget.toId,
    email: widget.toEmail,
  );
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<OwnerRepository>().sendMessage(
        title: _title.text.trim(),
        body: _body.text.trim(),
        to: _to.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // shortcut: the newest users the server lists (its search box filters them); a server search when there are many.
  Future<void> _pickTo() async {
    final l = AppLocalizations.of(context);
    final users = await context.read<OwnerRepository>().listUsers();
    if (!mounted) return;
    final picked = await showBasePicker<({String? id, String? email})>(
      context,
      title: l.ownerMessageToLabel,
      options: [
        (id: null, email: null),
        for (final u in users) (id: u.id, email: u.email),
      ],
      selected: _to,
      label: (o) => o.email ?? l.ownerMessageEveryone,
    );
    if (picked != null && mounted) setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final ready = _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.ownerMessageNew,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (widget.toId != null)
            Text(
              l.ownerMessageTo(widget.toEmail ?? ''),
              style: TextStyle(color: nb.inkSoft),
            )
          else ...[
            const SizedBox(height: spaceS),
            BaseTile(
              key: const ValueKey('message-to'),
              style: TileStyle.plain, // the sheet's own gutter: an outlined tile would indent twice
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: _to.email ?? l.ownerMessageEveryone,
              subtitle: l.ownerMessageToLabel,
              trailing: const Icon(Icons.expand_more),
              onTap: _busy ? null : _pickTo,
            ),
          ],
          const SizedBox(height: spaceM),
          TextField(
            key: const ValueKey('message-title'),
            controller: _title,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.ownerMessageTitle),
          ),
          TextField(
            key: const ValueKey('message-body'),
            controller: _body,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.ownerMessageBody),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: spaceXs),
              child: Text(
                errorText(l, e),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: spaceS),
          PanelActions(
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              BusyButton(
                key: const ValueKey('message-send'),
                kind: BusyButtonKind.filled,
                icon: Icons.send,
                label: l.ownerMessageSend,
                busyLabel: l.ownerMessageSending,
                busy: _busy,
                onPressed: ready && !_busy ? _send : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
