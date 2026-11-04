import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/new_password_fields.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
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
      await context.read<AuthController>().changePassword(
        _current.text,
        _next.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(l, e, changingPassword: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void toAccount() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/account');
      }
    }

    return AuthCover(
      kicker: l.changePasswordTitle,
      showBack: true,
      onBack: toAccount,
      footer: CoverLink(
        label: l.backToAccount,
        onPressed: toAccount,
        icon: Icons.arrow_back,
        iconBefore: true,
      ),
      children: [
        if (_done)
          FormMessage(l.changePasswordDone, success: true)
        else
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _current,
                    label: l.currentPassword,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').isEmpty ? l.errWrongCurrentPassword : null,
                  ),
                  const SizedBox(height: 16),
                  NewPasswordFields(
                    password: _next,
                    confirm: _confirm,
                    label: l.newPassword,
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: 24),
                  BusyButton(
                    label: l.changePasswordButton,
                    busy: _busy,
                    onPressed: _submit,
                  ),
                  FormMessage(_error),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
