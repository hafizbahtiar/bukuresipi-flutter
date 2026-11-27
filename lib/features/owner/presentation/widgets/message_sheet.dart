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
/// [toEmail]) or, opened without one, to everyone or a user picked on the To row. Starts on a template (one step of
/// the same sheet; Back returns to them); the app update one is sent as kind update (a tap opens Play). Sends it
/// itself; pops true once sent.
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
  final _to = TextEditingController(); // the To field: "Everyone" or an email
  String? _toId; // null = everyone
  Map<String, String> _ids = const {}; // email -> user id, for the To field
  bool _busy = false;
  Object? _error;
  bool _picked = false; // the template step is done: the form shows
  bool _forward = true;
  String _kind = 'message';

  @override
  void dispose() {
    _to.dispose();
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
        to: widget.toId ?? _toId,
        kind: _kind,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.toId != null) return;
    // shortcut: the newest users the server lists (the picker's search filters them); a server search when there are many.
    context.read<OwnerRepository>().listUsers().then((users) {
      if (mounted) {
        setState(() => _ids = {for (final u in users) u.email: u.id});
      }
    }, onError: (_) {}); // offline: everyone is still offered
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_to.text.isEmpty) {
      _to.text = AppLocalizations.of(context).ownerMessageEveryone;
    }
  }

  /// The 10 templates: (label, title, body); the first is the app update.
  List<(String, String, String)> _templates(AppLocalizations l) => [
    (l.msgTpl1Label, l.msgTpl1Title, l.msgTpl1Body),
    (l.msgTpl2Label, l.msgTpl2Title, l.msgTpl2Body),
    (l.msgTpl3Label, l.msgTpl3Title, l.msgTpl3Body),
    (l.msgTpl4Label, l.msgTpl4Title, l.msgTpl4Body),
    (l.msgTpl5Label, l.msgTpl5Title, l.msgTpl5Body),
    (l.msgTpl6Label, l.msgTpl6Title, l.msgTpl6Body),
    (l.msgTpl7Label, l.msgTpl7Title, l.msgTpl7Body),
    (l.msgTpl8Label, l.msgTpl8Title, l.msgTpl8Body),
    (l.msgTpl9Label, l.msgTpl9Title, l.msgTpl9Body),
    (l.msgTpl10Label, l.msgTpl10Title, l.msgTpl10Body),
  ];

  /// [n] = the template's number (1 = app update); null = write your own.
  void _pick(int? n, AppLocalizations l) => setState(() {
    final t = n == null ? null : _templates(l)[n - 1];
    _title.text = t?.$2 ?? '';
    _body.text = t?.$3 ?? '';
    _kind = n == 1 ? 'update' : 'message';
    _forward = true;
    _picked = true;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SheetSwitcher(
      forward: _forward,
      child: _picked ? _form(l) : _templateStep(l),
    );
  }

  Widget _templateStep(AppLocalizations l) => ListView(
    key: const ValueKey('message-step-templates'),
    shrinkWrap: true, // as tall as its rows; scrolls on a small screen
    padding: const EdgeInsets.only(bottom: spaceM),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
        child: Text(
          l.ownerMessageTemplates,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      BaseTile(
        key: const ValueKey('tpl-blank'),
        dense: true,
        leading: const Icon(Icons.edit_outlined),
        title: l.ownerMessageBlank,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pick(null, l),
      ),
      for (final (i, (label, title, _)) in _templates(l).indexed)
        BaseTile(
          key: ValueKey('tpl-${i + 1}'),
          dense: true,
          leading: Icon(i == 0 ? Icons.system_update : Icons.campaign_outlined),
          title: label,
          subtitle: title,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pick(i + 1, l),
        ),
    ],
  );

  Widget _form(AppLocalizations l) {
    final nb = Notebook.of(context);
    final ready = _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;
    return SingleChildScrollView(
      key: const ValueKey('message-step-form'),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, spaceM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetStepTitle(
            title: l.ownerMessageNew,
            onBack: _busy
                ? () {}
                : () => setState(() {
                    _forward = false;
                    _picked = false;
                  }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spaceM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.toId != null)
                  Text(
                    l.ownerMessageTo(widget.toEmail ?? ''),
                    style: TextStyle(color: nb.inkSoft),
                  )
                else ...[
                  const SizedBox(height: spaceS),
                  PickerField(
                    key: const ValueKey('message-to'),
                    controller: _to,
                    label: l.ownerMessageToLabel,
                    options: [l.ownerMessageEveryone, ..._ids.keys],
                    onPicked: (picked) => setState(() => _toId = _ids[picked]),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
          ),
        ],
      ),
    );
  }
}
