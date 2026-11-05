import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/google_auth.dart';
import '../auth_controller.dart';
import '../../../family/presentation/ask.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../push/push_controller.dart';
import '../auth_text.dart';

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

  /// Account > Google: link asks Google for the account; unlink asks first (they then sign in with the password).
  Future<void> _google(bool linked) async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final google = context.read<GoogleAuth?>();
    try {
      if (linked) {
        final yes = await showNotebookDialog(
          context,
          message: l.googleUnlinkConfirm,
          tone: DialogTone.danger,
          confirmLabel: l.googleUnlink,
        );
        if (!yes) return;
        await auth.unlinkGoogle();
        _snack(l.googleUnlinked);
      } else {
        final token = await google?.idToken();
        if (token == null) return; // closed the sheet
        await auth.linkGoogle(token);
        _snack(l.googleLinked);
      }
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  /// Google-only: the reset link sets the first password (the same page as "Forgot password").
  Future<void> _setPassword() async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    try {
      await auth.forgotPassword(auth.user!.email);
      _snack(l.setPasswordSent);
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = context.watch<AuthController>();
    final locale = context.watch<LocaleController>();
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
              if (context.watch<PushController?>() case final push?)
                NotebookRow(
                  mark: mark(Icons.notifications_none),
                  onTap: () => push.setEnabled(!push.enabled),
                  trailing: Switch(
                    value: push.enabled,
                    onChanged: push.setEnabled,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.pushRow),
                      Text(
                        l.pushRowHint,
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
                mark: mark(Icons.translate),
                onTap: () => locale.setLang(locale.lang == 'ms' ? 'en' : 'ms'),
                trailing: _LangChoice(
                  lang: locale.lang,
                  onChanged: locale.setLang,
                ),
                child: Text(l.language),
              ),
              NotebookRow(
                mark: mark(Icons.alternate_email),
                // Changing the email asks for the password: a Google-only account sets one first.
                onTap: user.hasPassword
                    ? () => context.push('/account/email')
                    : null,
                trailing: user.hasPassword ? next : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.changeEmailTitle),
                    if (!user.hasPassword)
                      Text(
                        l.changeEmailNeedsPassword,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                  ],
                ),
              ),
              NotebookRow(
                mark: mark(Icons.lock_outline),
                onTap: user.hasPassword
                    ? () => context.push('/account/password')
                    : _setPassword,
                trailing: user.hasPassword ? next : null,
                child: user.hasPassword
                    ? Text(l.changePasswordTitle)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.setPasswordTitle),
                          Text(
                            l.setPasswordHint,
                            style: text.bodySmall?.copyWith(color: nb.inkSoft),
                          ),
                        ],
                      ),
              ),
              // Linked: shown everywhere (with Unlink when there is a password). Not linked: only where Google works.
              if (user.google || context.watch<GoogleAuth?>() != null)
                NotebookRow(
                  mark: mark(Icons.link),
                  onTap: user.google && !user.hasPassword
                      ? null
                      : () => _google(user.google),
                  trailing: user.google
                      ? (user.hasPassword
                            ? Text(
                                l.googleUnlink,
                                style: TextStyle(color: nb.margin),
                              )
                            : null)
                      : next,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.googleRow),
                      Text(
                        user.google
                            ? (user.hasPassword
                                  ? l.googleLinkedHint
                                  : l.googleOnlyHint)
                            : l.googleLinkHint,
                        style: text.bodySmall?.copyWith(
                          color: user.google ? nb.pandanDeep : nb.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              NotebookRow(
                mark: mark(Icons.devices_outlined),
                onTap: () => context.push('/account/sessions'),
                trailing: next,
                child: Text(l.sessionsRow),
              ),
              if (user.isOwner)
                NotebookRow(
                  mark: mark(Icons.admin_panel_settings_outlined),
                  onTap: () => context.push('/owner'),
                  trailing: next,
                  child: Text(l.ownerTitle),
                ),
              NotebookRow(
                mark: mark(Icons.info_outline),
                onTap: () => context.push('/about'),
                trailing: next,
                child: Text(l.aboutTitle),
              ),
              NotebookRow(
                mark: mark(Icons.favorite_outline),
                onTap: () => context.push('/credits'),
                child: Text(l.creditsTitle),
              ),
              if (!user.isOwner)
                NotebookRow(
                  mark: mark(Icons.delete_forever_outlined, nb.margin),
                  onTap: () => context.push('/auth/delete'),
                  trailing: next,
                  child: Text(l.deleteAccountTitle),
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

/// BM / EN, the chosen one marked with a kunyit highlighter stroke.
class _LangChoice extends StatelessWidget {
  const _LangChoice({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (code, label) in const [('ms', 'BM'), ('en', 'EN')])
          Semantics(
            button: true,
            selected: code == lang,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(code),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: code == lang
                      ? nb.kunyit.withValues(alpha: 0.55)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: code == lang
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: code == lang ? nb.ink : nb.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
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
