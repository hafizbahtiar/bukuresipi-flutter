import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/base.dart'
    show MenuAction, showPhotoSourceSheet;
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/photo_editor_page.dart';
import '../../../../core/widgets/photo_sheet.dart';
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
  static const _avatarHero = 'photo:account-avatar';

  /// Tapping the picture: with one, it opens full size with Change and Remove under it; with none, straight to
  /// picking one.
  Future<void> _avatarTap() async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final user = auth.user!;
    if (user.avatar == null) return _changeAvatar();
    final bytes = await auth
        .avatar(user.id, user.avatar!)
        .catchError((Object _) => null);
    if (!mounted) return;
    if (bytes == null) return _snack(l.errUnknown);
    return showPhotoDialog(
      context,
      bytes,
      heroTag: _avatarHero,
      heroRadius: 20, // the 40 px avatar's circle
      aspectRatio: 1, // avatars are cropped square
      actions: [
        MenuAction(
          icon: Icons.edit_outlined,
          label: l.avatarActionChange,
          onTap: _changeAvatar,
        ),
        MenuAction(
          icon: Icons.delete_outline,
          label: l.avatarActionRemove,
          danger: true,
          onTap: _removeAvatar,
        ),
      ],
    );
  }

  /// Camera or photos, then the square crop, then upload. An upload error shows; the old picture stays.
  Future<void> _changeAvatar() async {
    final l = AppLocalizations.of(context);
    final source = await showPhotoSourceSheet(context, camera: l.coverCamera);
    if (source == null || !mounted) return;
    final path = await pickPhoto(
      context,
      ratios: [('1:1', 1)],
      maxSide: 1024,
      source: source,
    );
    if (path == null || !mounted) return;
    await _saveAvatar(() => context.read<AuthController>().setAvatar(path));
  }

  Future<void> _removeAvatar() async {
    final l = AppLocalizations.of(context);
    final sure = await showNotebookDialog(
      context,
      message: l.avatarRemoveConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.avatarActionRemove,
    );
    if (!sure || !mounted) return;
    await _saveAvatar(() => context.read<AuthController>().removeAvatar());
  }

  Future<void> _saveAvatar(Future<void> Function() save) async {
    final l = AppLocalizations.of(context);
    setState(() => _avatarBusy = true);
    try {
      await save();
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
            padding: EdgeInsets.only(bottom: navRoom(context)),
            children: [
              NotebookRow(
                mark: Semantics(
                  button: true,
                  label: user.avatar == null ? l.avatarAdd : l.avatarView,
                  child: InkWell(
                    key: const ValueKey('account-avatar'),
                    customBorder: const CircleBorder(),
                    onTap: _avatarBusy ? null : _avatarTap,
                    child: _avatarBusy
                        ? const SizedBox.square(
                            dimension: 40,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : PhotoHero(
                            tag: _avatarHero,
                            child: Avatar(
                              userId: user.id,
                              avatar: user.avatar,
                              name: user.name ?? user.email,
                            ),
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
              if (user.isOwner)
                NotebookRow(
                  mark: mark(Icons.admin_panel_settings_outlined),
                  onTap: () => context.push('/owner'),
                  trailing: next,
                  child: Text(l.ownerTitle),
                ),
              NotebookRow(
                key: const ValueKey('account-badges'),
                mark: mark(Icons.military_tech_outlined),
                onTap: () => context.push('/badges'),
                trailing: next,
                child: Text(l.badgesTitle),
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
