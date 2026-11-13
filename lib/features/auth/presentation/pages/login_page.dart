import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/google_button.dart';
import '../widgets/passkey_button.dart';

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
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return AuthCover(
      kicker: l.loginTitle,
      subtitle: l.loginSubtitle,
      bottomAligned: true,
      top: const CoverBrand(),
      footer: CoverLink(
        label: l.toRegister,
        onPressed: () => context.push('/register'),
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CoverField(
                  controller: _email,
                  label: l.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => emailError(l, v),
                ),
                const SizedBox(height: 12),
                // Login only checks that something was typed: the server decides, and old passwords may predate rules.
                _CoverField(
                  controller: _password,
                  label: l.password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v ?? '').isEmpty ? l.errInvalidCredentials : null,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    style: TextButton.styleFrom(
                      foregroundColor: Notebook.light.pandanDeep,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                      textStyle: TextStyle(
                        fontFamily: family,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Notebook.light.pandanDeep.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Text(l.toForgot),
                  ),
                ),
                const SizedBox(height: 6),
                _CoverButton(
                  label: l.loginButton,
                  busy: _busy,
                  onPressed: _submit,
                ),
                PasskeyButton(onError: (e) => setState(() => _error = e)),
                GoogleButton(onError: (e) => setState(() => _error = e)),
                if (_error case final error?) _CoverError(error),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A field written on one of the label's rules.
class _CoverField extends StatefulWidget {
  const _CoverField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final bool obscure;
  final void Function(String)? onSubmitted;

  @override
  State<_CoverField> createState() => _CoverFieldState();
}

class _CoverFieldState extends State<_CoverField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final underline = BorderSide(color: Notebook.light.rule, width: 1.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Notebook.light.inkSoft,
          ),
        ),
        const SizedBox(height: 2),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          autocorrect: false,
          enableSuggestions: !widget.obscure,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          style: TextStyle(
            fontFamily: family,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Notebook.light.ink,
          ),
          cursorColor: Notebook.light.pandan,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
            border: UnderlineInputBorder(borderSide: underline),
            enabledBorder: UnderlineInputBorder(borderSide: underline),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Notebook.light.pandan, width: 2),
            ),
            errorStyle: TextStyle(
              fontFamily: family,
              fontSize: 11,
              height: 1.2,
              color: Notebook.light.margin,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? l.showPassword : l.hidePassword,
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Notebook.light.inkSoft,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: Notebook.light.pandan,
        foregroundColor: Notebook.light.paper,
        disabledBackgroundColor: Notebook.light.pandan.withValues(alpha: 0.55),
        disabledForegroundColor: Notebook.light.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Notebook.light.paper,
              ),
            )
          : Text(label),
    );
  }
}

/// An error written in red on the label.
class _CoverError extends StatelessWidget {
  const _CoverError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Notebook.light.margin.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Notebook.light.margin.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: Notebook.light.margin),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: family,
                fontSize: 12.5,
                height: 1.3,
                color: const Color(0xFF8C2B26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
