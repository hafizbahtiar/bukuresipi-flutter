import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/log.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../core/settings/theme_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_reveal.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../core/widgets/pill_switch.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../push/push_controller.dart';
import '../../data/google_auth.dart';
import '../auth_controller.dart';
import '../auth_text.dart';

/// Account > Settings: sign-in and security (email, password, Google, devices), the app (notifications, language),
/// and about. The Account tab keeps the profile and the user's own things.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _themePill = GlobalKey();

  /// The new theme spreads from the theme pill as a circle; a choice that looks the same (System while the phone
  /// already matches) just switches.
  void _setTheme(ThemeMode mode) {
    final theme = context.read<ThemeController>();
    final then = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final reveal = ThemeReveal.maybeOf(context);
    final pill = _themePill.currentContext?.findRenderObject() as RenderBox?;
    if (then == Theme.of(context).brightness ||
        reveal == null ||
        pill == null) {
      theme.setMode(mode);
      return;
    }
    reveal.change(
      pill.localToGlobal(pill.size.center(Offset.zero)),
      () => theme.setMode(mode),
    );
  }

  // Called after awaits: the page may be gone by then.
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
        log('google: linked');
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
    final theme = context.watch<ThemeController>();
    final user = auth.user;
    if (user == null) return const Scaffold();
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    Icon mark(IconData icon, [Color? color]) =>
        Icon(icon, size: 20, color: color ?? nb.inkSoft);
    final next = Icon(Icons.chevron_right, color: nb.inkSoft);

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.settingsTitle)),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Section(l.settingsSecurity),
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
            _Section(l.settingsApp),
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
              mark: mark(Icons.translate),
              onTap: () => locale.setLang(locale.lang == 'ms' ? 'en' : 'ms'),
              trailing: PillSwitch(
                value: locale.lang,
                onChanged: locale.setLang,
                options: const [
                  ('ms', Text('BM'), null),
                  ('en', Text('EN'), null),
                ],
              ),
              child: Text(l.language),
            ),
            NotebookRow(
              mark: mark(Icons.contrast),
              trailing: PillSwitch(
                key: _themePill,
                value: theme.mode,
                onChanged: _setTheme,
                options: [
                  (
                    ThemeMode.light,
                    const Icon(Icons.light_mode_outlined, size: 18),
                    l.themeLight,
                  ),
                  (
                    ThemeMode.dark,
                    const Icon(Icons.dark_mode_outlined, size: 18),
                    l.themeDark,
                  ),
                  (
                    ThemeMode.system,
                    const Icon(Icons.phone_android, size: 18),
                    l.themeSystem,
                  ),
                ],
              ),
              child: Text(l.theme),
            ),
            _Section(l.settingsAbout),
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
          ],
        ),
      ),
    );
  }
}

/// A small heading between groups of rows.
class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 20, 20, 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Notebook.of(context).inkSoft,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// BM / EN, the chosen one marked with a kunyit highlighter stroke.
/// A small inline choice: each option is (value, what it shows, its name for screen readers when it shows an icon).
