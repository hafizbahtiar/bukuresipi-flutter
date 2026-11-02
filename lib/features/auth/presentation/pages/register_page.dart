import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/settings/locale_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/new_password_fields.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
      await context.read<AuthController>().register(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        lang: context.read<LocaleController>().lang,
      );
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.registerTitle,
      subtitle: l.registerSubtitle,
      showBack: false,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l.name,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
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
                NewPasswordFields(
                  password: _password,
                  confirm: _confirm,
                  label: l.password,
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 24),
                BusyButton(
                  label: l.registerButton,
                  busy: _busy,
                  onPressed: _submit,
                ),
                FormMessage(_error),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l.toLogin),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
