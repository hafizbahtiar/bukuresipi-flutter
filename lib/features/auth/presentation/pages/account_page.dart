import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/settings/locale_controller.dart';
import '../../../../core/widgets/notebook.dart';
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
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.accountTitle)),
      body: RefreshIndicator(
        onRefresh: () => auth.refreshUser().catchError(
          (Object e) => _snack(errorText(l, e)),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  (user.name ?? user.email).characters.first.toUpperCase(),
                ),
              ),
              title: Text(user.name ?? user.email),
              subtitle: user.name == null ? null : Text(user.email),
            ),
            ListTile(
              leading: Icon(
                user.emailVerified
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                color: user.emailVerified ? c.primary : c.error,
              ),
              title: Text(
                user.emailVerified ? l.emailVerified : l.emailNotVerified,
              ),
              subtitle: user.emailVerified ? null : Text(l.resendVerification),
              trailing: _sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: user.emailVerified || _sending ? null : _resend,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l.changePasswordTitle),
              onTap: () => context.push('/account/password'),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l.language),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ms', label: Text('BM')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {locale.lang},
                onSelectionChanged: (s) => locale.setLang(s.first),
                showSelectedIcon: false,
              ),
            ),
            if (user.isOwner)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(l.ownerTitle),
                onTap: () => context.push('/owner'),
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: c.error),
              title: Text(l.signOut, style: TextStyle(color: c.error)),
              onTap: () => auth.logout(),
            ),
          ],
        ),
      ),
    );
  }
}
