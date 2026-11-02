import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().login(
        _email.text,
        _password.text,
      ); // router moves on
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
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
    return AuthScaffold(
      title: l.loginTitle,
      subtitle: l.loginSubtitle,
      showBack: false,
      children: [
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
                  decoration: InputDecoration(labelText: l.email),
                  validator: (v) => emailError(l, v),
                ),
                const SizedBox(height: 16),
                // Login only checks that something was typed: the server decides, and old passwords may predate rules.
                PasswordField(
                  controller: _password,
                  label: l.password,
                  validator: (v) =>
                      (v ?? '').isEmpty ? l.errInvalidCredentials : null,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: Text(l.toForgot),
                  ),
                ),
                const SizedBox(height: 8),
                BusyButton(
                  label: l.loginButton,
                  busy: _busy,
                  onPressed: _submit,
                ),
                FormMessage(_error),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(l.toRegister),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
