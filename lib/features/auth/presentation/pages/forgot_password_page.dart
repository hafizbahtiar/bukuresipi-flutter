import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
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
      await context.read<AuthController>().forgotPassword(_email.text);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void toLogin() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
    }

    return AuthCover(
      kicker: l.forgotTitle,
      subtitle: _done ? null : l.forgotText,
      showBack: true,
      onBack: toLogin,
      footer: CoverLink(
        label: l.toLoginButton,
        onPressed: toLogin,
        icon: Icons.arrow_back,
        iconBefore: true,
      ),
      children: [
        if (_done)
          FormMessage(l.forgotDone, success: true)
        else
          Form(
            key: _form,
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
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                BusyButton(
                  label: l.forgotButton,
                  busy: _busy,
                  onPressed: _submit,
                ),
                FormMessage(_error),
              ],
            ),
          ),
      ],
    );
  }
}
