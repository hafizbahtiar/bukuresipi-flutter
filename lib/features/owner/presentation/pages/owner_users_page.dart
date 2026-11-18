import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../../core/widgets/deleting_overlay.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../widgets/user_action_sheets.dart';

/// Owner: users, newest first, searchable by email. Actions: end their sessions, ban / unban, delete the account.
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

  /// Picking users for a bulk delete: the Select button or a long-press starts it.
  bool _picking = false;
  final _picked = <String>{};

  /// A bulk delete running: how many are done of how many (the overlay's label).
  ({int done, int total})? _deleting;

  void _stopPicking() => setState(() {
    _picking = false;
    _picked.clear();
  });

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
          _picked.retainAll(users.map((u) => u.id)); // gone ones unpicked
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
    final error = Theme.of(context).colorScheme.error;
    // The owner account is never banned or deleted (the API refuses it too).
    final other = u.role != 'owner';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UserTile(user: u),
            ListTile(
              key: const ValueKey('user-logout'),
              leading: Icon(Icons.logout, color: error),
              title: Text(l.ownerEndSessions),
              onTap: () => Navigator.pop(context, 'logout'),
            ),
            if (other && u.ban != null)
              ListTile(
                key: const ValueKey('user-unban'),
                leading: const Icon(Icons.lock_open),
                title: Text(l.ownerUnban),
                onTap: () => Navigator.pop(context, 'unban'),
              )
            else if (other)
              ListTile(
                key: const ValueKey('user-ban'),
                leading: Icon(Icons.block, color: error),
                title: Text(l.ownerBan),
                onTap: () => Navigator.pop(context, 'ban'),
              ),
            if (other)
              ListTile(
                key: const ValueKey('user-delete'),
                leading: Icon(Icons.delete_forever_outlined, color: error),
                title: Text(l.ownerDeleteUser, style: TextStyle(color: error)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'logout':
        await _endSessions(u);
      case 'ban':
        await _ban(u);
      case 'unban':
        await _run(
          () => context.read<OwnerRepository>().unban(u.id),
          l.ownerUnbanned,
        );
      case 'delete':
        await _delete(u);
    }
  }

  /// Runs an owner action, says it worked (or why not) and reloads the list.
  Future<void> _run(Future<void> Function() call, String done) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _ban(OwnerUser u) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final r = await showNotebookSheet<({int? days, String reason})>(
      context,
      builder: (_) => BanSheet(email: u.email),
    );
    if (r == null || !mounted) return;
    await _run(
      () => repo.ban(u.id, days: r.days, reason: r.reason),
      l.ownerBanned,
    );
  }

  Future<void> _delete(OwnerUser u) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final r = await showNotebookSheet<({String reason, bool banEmail})>(
      context,
      builder: (_) => DeleteUserSheet(email: u.email),
    );
    if (r == null || !mounted) return;
    await _run(
      () => repo.deleteUser(u.id, reason: r.reason, banEmail: r.banEmail),
      l.ownerDeleted,
    );
  }

  /// Long-press or, while picking, a tap: picks or unpicks [u]. The owner account is never picked.
  void _toggle(OwnerUser u) {
    if (u.role == 'owner') return;
    setState(() {
      _picking = true;
      _picked.contains(u.id) ? _picked.remove(u.id) : _picked.add(u.id);
    });
  }

  /// One reason for every picked account, then each deleted in turn (the API has no bulk call); failures are counted.
  Future<void> _deletePicked() async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final ids = [..._picked];
    if (ids.isEmpty) return;
    final r = await showNotebookSheet<({String reason, bool banEmail})>(
      context,
      builder: (_) => DeleteUserSheet(email: l.ownerAccounts(ids.length)),
    );
    if (r == null || !mounted) return;
    var failed = 0;
    setState(() => _deleting = (done: 0, total: ids.length));
    try {
      for (final (n, id) in ids.indexed) {
        try {
          await repo.deleteUser(id, reason: r.reason, banEmail: r.banEmail);
        } catch (_) {
          failed++;
        }
        if (mounted) {
          setState(() => _deleting = (done: n + 1, total: ids.length));
        }
      }
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l.ownerDeletedMany(ids.length - failed),
            if (failed > 0) l.ownerDeleteFailed(failed),
          ].join('. '),
        ),
      ),
    );
    _stopPicking();
    await _load();
  }

  Future<void> _endSessions(OwnerUser u) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final messenger = ScaffoldMessenger.of(context);
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
    final picking = _picking;
    return PopScope(
      // Back while picking stops picking first.
      canPop: !picking && _deleting == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _deleting == null) _stopPicking();
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              leading: picking
                  ? IconButton(
                      key: const ValueKey('pick-cancel'),
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context)
                          .cancelButtonLabel,
                      onPressed: _stopPicking,
                    )
                  : null,
              title: Text(
                picking ? l.ownerPicked(_picked.length) : l.ownerUsers,
              ),
              actions: [
                if (picking) ...[
                  IconButton(
                    key: const ValueKey('pick-all'),
                    icon: const Icon(Icons.select_all),
                    tooltip: l.ownerPickAll,
                    onPressed: () => setState(
                      () => _picked.addAll([
                        for (final u in users ?? <OwnerUser>[])
                          if (u.role != 'owner') u.id,
                      ]),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('pick-delete'),
                    icon: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: l.ownerDeleteUser,
                    onPressed: _picked.isEmpty ? null : _deletePicked,
                  ),
                ],
              ],
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
                          child: Text(
                            l.ownerNoUsers,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _UserTile(
                        user: users[i],
                        picked: picking ? _picked.contains(users[i].id) : null,
                        onTap: () =>
                            picking ? _toggle(users[i]) : _open(users[i]),
                        onLongPress: () => _toggle(users[i]),
                      ),
                    ),
            ),
          ),
          if (_deleting case (:final done, :final total))
            DeletingOverlay(
              key: const ValueKey('deleting'),
              label: l.ownerDeleting(done, total),
            ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    this.onTap,
    this.onLongPress,
    this.picked,
  });

  final OwnerUser user;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// null = not picking; else a tick box (none for the owner account, which is never picked).
  final bool? picked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final joined = MaterialLocalizations.of(context)
        .formatMediumDate(user.createdAt.toLocal());
    return ListTile(
      leading: picked == null || user.role == 'owner'
          ? null
          : Checkbox(value: picked, onChanged: (_) => onTap?.call()),
      selected: picked ?? false,
      title: Text(user.email),
      subtitle: Text(
        [
          l.ownerJoined(joined),
          [
            l.ownerShareCount(user.shares),
            if (!user.verified) l.ownerUnverified,
            if (user.role == 'owner') l.ownerTitle,
          ].join(', '),
          if (user.ban case final ban?)
            ban.until == null
                ? l.ownerBannedForGood
                : l.ownerBannedUntil(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(ban.until!.toLocal()),
                  ),
        ].join('\n'),
      ),
      trailing: user.ban != null
          ? Icon(Icons.block, color: Theme.of(context).colorScheme.error)
          : user.verified
          ? null
          : Icon(
              Icons.mark_email_unread_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
