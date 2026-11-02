import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../load_view.dart';

/// Owner: users, newest first, searchable by email. The one action is ending a user's sessions.
class OwnerUsersPage extends StatefulWidget {
  const OwnerUsersPage({super.key});

  @override
  State<OwnerUsersPage> createState() => _OwnerUsersPageState();
}

class _OwnerUsersPageState extends State<OwnerUsersPage> {
  final _search = TextEditingController();
  List<OwnerUser>? _users;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _search.text.trim();
      final users = await context.read<OwnerRepository>().listUsers(
        query: q.isEmpty ? null : q,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(OwnerUser u) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final end = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UserTile(user: u),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.ownerEndSessions),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (end != true || !mounted) return;
    final yes = await showNotebookDialog(
      context,
      message: l.ownerEndSessionsConfirm(u.email),
      tone: DialogTone.danger,
      confirmLabel: l.ownerSignOut,
    );
    if (!yes) return;
    try {
      await repo.endSessions(u.id);
      messenger.showSnackBar(SnackBar(content: Text(l.ownerSessionsEnded)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final users = _users;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.ownerUsers),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: l.ownerSearchEmail,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: users == null
            ? null
            : users.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.ownerNoUsers, textAlign: TextAlign.center),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    _UserTile(user: users[i], onTap: () => _open(users[i])),
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, this.onTap});

  final OwnerUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final joined = MaterialLocalizations.of(context)
        .formatMediumDate(user.createdAt.toLocal());
    return ListTile(
      title: Text(user.email),
      subtitle: Text(
        [
          l.ownerJoined(joined),
          [
            l.ownerShareCount(user.shares),
            if (!user.verified) l.ownerUnverified,
            if (user.role == 'owner') l.ownerTitle,
          ].join(', '),
        ].join('\n'),
      ),
      trailing: user.verified
          ? null
          : Icon(
              Icons.mark_email_unread_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
      onTap: onTap,
    );
  }
}
