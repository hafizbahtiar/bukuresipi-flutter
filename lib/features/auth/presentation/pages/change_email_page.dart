import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/auth_widgets.dart';

/// New address + current password. The API emails a link to the new address; the email changes only when it is opened
/// (the verify link page), so this page ends at "check your inbox".
class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _sentTo;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().changeEmail(email, _password.text);
      if (mounted) setState(() => _sentTo = email);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = ApiException.from(e).code == 'email_taken'
              ? l
                    .errEmailInUse // not "sign in instead": they are signed in
              : errorText(l, e, changingPassword: true),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      kicker: l.changeEmailTitle,
      showBack: true,
      onBack: toAccount,
      footer: CoverLink(
        label: l.backToAccount,
        onPressed: toAccount,
        icon: Icons.arrow_back,
        iconBefore: true,
      ),
      children: [
        if (_sentTo case final to?)
          FormMessage(l.changeEmailSent(to), success: true)
        else
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l.newEmail),
                    validator: (v) => emailError(l, v),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: l.currentPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v ?? '').isEmpty ? l.errWrongCurrentPassword : null,
                  ),
                  const SizedBox(height: 24),
                  BusyButton(
                    label: l.changeEmailButton,
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
