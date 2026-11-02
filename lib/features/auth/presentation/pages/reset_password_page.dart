import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_widgets.dart';

/// Opened from the reset email (App Link https://bukuresipi.com/auth/reset?token=...).
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  bool _done = false;
  bool _dead = false; // link expired / used / missing
  String? _error;

  @override
  void initState() {
    super.initState();
    _dead = (widget.token ?? '').isEmpty;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().resetPassword(widget.token!, _password.text);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      final text = errorText(l, e);
      setState(() => text == l.errInvalidToken ? _dead = true : _error = text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.resetTitle,
      showBack: false,
      children: [
        if (_done) ...[
          FormMessage(l.resetDone, success: true),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/login'), child: Text(l.toLoginButton)),
        ] else if (_dead) ...[
          FormMessage(l.errInvalidToken),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/forgot'), child: Text(l.requestNewLink)),
        ] else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PasswordField(
                controller: _password,
                label: l.newPassword,
                helper: l.passwordHint,
                newPassword: true,
                validator: (v) => passwordError(l, v),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              BusyButton(label: l.resetButton, busy: _busy, onPressed: _submit),
              FormMessage(_error),
            ]),
          ),
      ],
    );
  }
}
