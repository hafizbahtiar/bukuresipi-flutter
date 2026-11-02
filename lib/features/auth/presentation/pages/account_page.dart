import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _sending = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
                    Text(
                      user.name ?? user.email,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.name != null)
                      Text(
                        user.email,
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                      ),
                  ],
                ),
              ),
              NotebookRow(
                mark: mark(
                  verified ? Icons.check : Icons.mail_outline,
                  verified ? nb.pandan : nb.margin,
                ),
                onTap: verified || _sending ? null : _resend,
                trailing: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(verified ? l.emailVerified : l.emailNotVerified),
                    if (!verified)
                      Text(
                        l.resendVerification,
                        style: text.bodySmall?.copyWith(
                          color: nb.pandanDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              NotebookRow(
                mark: mark(Icons.translate),
                trailing: _LangChoice(
                  lang: locale.lang,
                  onChanged: locale.setLang,
                ),
                child: Text(l.language),
              ),
              NotebookRow(
                mark: mark(Icons.lock_outline),
                onTap: () => context.push('/account/password'),
                trailing: next,
                child: Text(l.changePasswordTitle),
              ),
              if (user.isOwner)
                NotebookRow(
                  mark: mark(Icons.admin_panel_settings_outlined),
                  onTap: () => context.push('/owner'),
                  trailing: next,
                  child: Text(l.ownerTitle),
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
