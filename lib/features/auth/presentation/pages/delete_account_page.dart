import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/google_auth.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/auth_widgets.dart';

/// Account deletion (App Store 5.1.1(v), Google Play). Same path as the website page, so its link opens here too;
/// works signed out: email + password are the proof.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _form = GlobalKey<FormState>();
  // Made in initState, not `late`: the Google path never shows the email field, and a lazy one would first be built
  // in dispose(), where reading the context throws.
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = context.read<AuthController>().user?.email ?? '';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final yes = await showNotebookDialog(
      context,
      title: l.deleteAccountTitle,
      message: l.deleteAccountConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.deleteAccountButton,
    );
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().deleteAccount(
        _email.text.trim(),
        _password.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A Google-only account has no password: a fresh Google ID token proves it is theirs.
  Future<void> _submitGoogle(GoogleAuth google) async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final yes = await showNotebookDialog(
      context,
      title: l.deleteAccountTitle,
      message: l.deleteAccountConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.deleteAccountButton,
    );
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await google.idToken();
      if (token == null) return;
      await auth.deleteAccountWithGoogle(token);
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
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void back() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    final google = context.watch<GoogleAuth?>();
    final googleOnly =
        google != null &&
        context.watch<AuthController>().user?.hasPassword == false;
    return AuthCover(
      kicker: l.deleteAccountTitle,
      subtitle: _done ? null : l.deleteAccountText,
      showBack: true,
      onBack: back,
      children: [
        if (_done)
          FormMessage(l.deleteAccountDone, success: true)
        else if (googleOnly)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.deleteWithGoogleHint),
              const SizedBox(height: 24),
              BusyButton(
                label: l.deleteWithGoogle,
                busy: _busy,
                onPressed: () => _submitGoogle(google),
              ),
              FormMessage(_error),
            ],
          )
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
                    decoration: InputDecoration(labelText: l.email),
                    validator: (v) => emailError(l, v),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: l.password,
                    validator: (v) =>
                        (v ?? '').isEmpty ? l.errInvalidCredentials : null,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  BusyButton(
                    label: l.deleteAccountButton,
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
