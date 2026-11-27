import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/widgets/owner_panel.dart';
import '../../domain/owner_repository.dart';

/// The owner's message: a title and text, to one user ([toId], named by [toEmail]) or everyone (both null), with or
/// without a push. Sends it itself; pops true once sent.
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
  bool _push = true;
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
        to: widget.toId,
        push: _push,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          Text(switch (widget.toEmail) {
            final email? => l.ownerMessageTo(email),
            null => l.ownerMessageTo(l.ownerMessageEveryone),
          }, style: TextStyle(color: nb.inkSoft)),
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
          Row(
            children: [
              Expanded(child: Text(l.ownerMessagePush)),
              Switch(
                key: const ValueKey('message-push'),
                value: _push,
                onChanged: (v) => setState(() => _push = v),
              ),
            ],
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
