import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/photo_editor_page.dart';
import '../../../../core/widgets/photo_viewer_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../../../family/presentation/ask.dart';
import '../../../family/presentation/family_controller.dart';
import '../auth_text.dart';
import '../widgets/avatar.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _sending = false;

  // Called after awaits: the page may be gone by then.
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _avatarBusy = false;

  /// The picture: view it full size, change (pick + square crop) or remove. Upload errors show; the old
  /// picture stays.
  Future<void> _avatarMenu({required bool has}) async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final choice = await showNotebookSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (has)
            ListTile(
              key: const ValueKey('avatar-view'),
              leading: const Icon(Icons.photo_outlined),
              title: Text(l.avatarView),
              onTap: () => Navigator.of(sheet).pop('view'),
            ),
          ListTile(
            leading: const Icon(Icons.add_a_photo_outlined),
            title: Text(has ? l.avatarChange : l.avatarAdd),
            onTap: () => Navigator.of(sheet).pop('change'),
          ),
          if (has)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: Text(l.avatarRemove),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'view') {
      final user = auth.user!;
      final bytes = await auth
          .avatar(user.id, user.avatar!)
          .catchError((Object _) => null);
      if (!mounted) return;
      if (bytes == null) return _snack(l.errUnknown);
      return PhotoViewerPage.open(context, bytes, title: user.name);
    }
    final path = choice == 'change'
        ? await pickPhoto(context, ratios: [('1:1', 1)], maxSide: 1024)
        : null;
    if (choice == 'change' && path == null) return;
    setState(() => _avatarBusy = true);
    try {
      await (path == null ? auth.removeAvatar() : auth.setAvatar(path));
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await context.read<AuthController>().resendVerification();
      _snack(l.resendDone);
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = context.watch<AuthController>();
    final user = auth.user;
    if (user == null) return const Scaffold();
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final verified = user.emailVerified;
    Icon mark(IconData icon, [Color? color]) =>
        Icon(icon, size: 20, color: color ?? nb.inkSoft);
    final next = Icon(Icons.chevron_right, color: nb.inkSoft);

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.accountTitle)),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: () => auth.refreshUser().catchError(
            (Object e) => _snack(errorText(l, e)),
          ),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              NotebookRow(
                mark: Semantics(
                  button: true,
                  label: user.avatar == null ? l.avatarAdd : l.avatarChange,
                  child: InkWell(
                    key: const ValueKey('account-avatar'),
                    customBorder: const CircleBorder(),
                    onTap: _avatarBusy
                        ? null
                        : () => _avatarMenu(has: user.avatar != null),
                    child: _avatarBusy
                        ? const SizedBox.square(
                            dimension: 40,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Avatar(
                            userId: user.id,
                            avatar: user.avatar,
                            name: user.name ?? user.email,
                          ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.name != null)
                      Text(
                        user.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    // The email shrinks (…) before the chip does: a long address never pushes it off.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: user.name == null
                                ? text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )
                                : text.bodyMedium?.copyWith(color: nb.inkSoft),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _VerifiedChip(
                          verified: verified,
                          sending: _sending,
                          onResend: _resend,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              NotebookRow(
                mark: mark(Icons.badge_outlined),
                onTap: () => askName(context),
                trailing: next,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.nameRow),
                    Text(
                      user.name ?? l.nameNotSet,
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                  ],
                ),
              ),
              NotebookRow(
                mark: mark(Icons.people_outline),
                onTap: () => context.push('/family'),
                trailing: next,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.familyTitle),
                    Text(
                      context.watch<FamilyController?>()?.family?.name ??
                          l.familyStart,
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                  ],
                ),
              ),
              NotebookRow(
                key: const ValueKey('account-receipts'),
                mark: mark(Icons.receipt_long_outlined),
                onTap: () => context.push('/receipts'),
                trailing: next,
                child: Text(l.receiptsTitle),
              ),
              if (user.isOwner)
                NotebookRow(
                  mark: mark(Icons.admin_panel_settings_outlined),
                  onTap: () => context.push('/owner'),
                  trailing: next,
                  child: Text(l.ownerTitle),
                ),
              NotebookRow(
                key: const ValueKey('account-usage'),
                mark: mark(Icons.speed_outlined),
                onTap: () => context.push('/usage'),
                trailing: next,
                child: Text(l.usageTitle),
              ),
              NotebookRow(
                key: const ValueKey('account-settings'),
                mark: mark(Icons.settings_outlined),
                onTap: () => context.push('/settings'),
                trailing: next,
                child: Text(l.settingsTitle),
              ),
              NotebookRow(
                mark: mark(Icons.logout, nb.margin),
                onTap: () async {
                  final yes = await showNotebookDialog(
                    context,
                    title: l.signOutTitle,
                    message: l.signOutConfirm,
                    tone: DialogTone.danger,
                    confirmLabel: l.signOut,
                  );
                  if (yes) await auth.logout();
                },
                child: Text(
                  l.signOut,
                  style: TextStyle(
                    color: nb.margin,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Verified" (green) or "Not verified" beside the email; the second one sends the link again when tapped.
class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({
    required this.verified,
    required this.sending,
    required this.onResend,
  });

  final bool verified;
  final bool sending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final color = verified ? nb.pandanDeep : nb.margin;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sending)
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(
              verified ? Icons.check : Icons.mail_outline,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 4),
          Text(
            verified ? l.emailVerifiedChip : l.emailNotVerifiedChip,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (verified) return chip;
    return Tooltip(
      message: l.resendVerification,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: sending ? null : onResend,
        child: chip,
      ),
    );
  }
}
