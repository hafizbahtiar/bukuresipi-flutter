import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().changePassword(_current.text, _next.text);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e, changingPassword: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.changePasswordTitle,
      children: [
        if (_done)
          FormMessage(l.changePasswordDone, success: true)
        else
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PasswordField(
                  controller: _current,
                  label: l.currentPassword,
                  validator: (v) => (v ?? '').isEmpty ? l.errWrongCurrentPassword : null,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _next,
                  label: l.newPassword,
                  helper: l.passwordHint,
                  newPassword: true,
                  validator: (v) => passwordError(l, v),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                BusyButton(label: l.changePasswordButton, busy: _busy, onPressed: _submit),
                FormMessage(_error),
              ]),
            ),
          ),
      ],
    );
  }
}
