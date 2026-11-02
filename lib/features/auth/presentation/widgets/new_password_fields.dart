import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_text.dart';
import '../password_strength.dart';
import 'auth_widgets.dart';

/// New password + live strength meter and checklist + confirmation. Used by register, reset and change password.
class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    super.key,
    required this.password,
    required this.confirm,
    required this.label,
    this.onSubmitted,
  });

  final TextEditingController password;
  final TextEditingController confirm;
  final String label;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordField(
          controller: password,
          label: label,
          newPassword: true,
          textInputAction: TextInputAction.next,
          validator: (v) => passwordError(l, v),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: password,
          builder: (_, v, _) => _Meter(v.text),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: confirm,
          label: l.confirmPassword,
          newPassword: true,
          validator: (v) => v == password.text ? null : l.errPasswordMismatch,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        ),
      ],
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final check = checkPassword(text);
    final strength = check.strength;
    final filled = text.isEmpty ? 0 : strength.index + 1;
    final color = switch (strength) {
      Strength.weak => c.error,
      Strength.fair => const Color(0xFFD9822B),
      Strength.good => const Color(0xFF6A9F3E),
      Strength.strong => c.primary,
    };
    final word = switch (strength) {
      Strength.weak => l.strengthWeak,
      Strength.fair => l.strengthFair,
      Strength.good => l.strengthGood,
      Strength.strong => l.strengthStrong,
    };

    Widget rule(bool ok, String label) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? c.primary : c.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: small?.copyWith(
                color: ok ? c.onSurface : c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < filled ? color : c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Text(
                l.passwordStrength,
                style: small?.copyWith(color: c.onSurfaceVariant),
              ),
              const Spacer(),
              if (text.isNotEmpty)
                Text(
                  word,
                  style: small?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        rule(check.length, l.ruleLength),
        rule(check.lower, l.ruleLower),
        rule(check.upper, l.ruleUpper),
        rule(check.number, l.ruleNumber),
        rule(check.symbol, l.ruleSymbol),
        rule(check.long, l.ruleLong),
      ],
    );
  }
}
