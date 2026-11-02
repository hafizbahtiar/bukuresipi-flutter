import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Same rules as the API (bukuresipi-hono password.ts / disposable.ts), checked before sending.
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? emailError(AppLocalizations l, String? v) => _email.hasMatch((v ?? '').trim()) ? null : l.errInvalidEmail;

String? passwordError(AppLocalizations l, String? v) {
  final p = v ?? '';
  final bytes = utf8.encode(p).length;
  return p.length < 8 || bytes > 72 || p.trim().isEmpty ? l.errWeakPassword : null;
}

/// API error code -> sentence for the user.
String errorText(AppLocalizations l, Object error, {bool changingPassword = false}) {
  final code = ApiException.from(error).code;
  return switch (code) {
    'invalid_credentials' => changingPassword ? l.errWrongCurrentPassword : l.errInvalidCredentials,
    'email_taken' => l.errEmailTaken,
    'disposable_email' => l.errDisposableEmail,
    'weak_password' => l.errWeakPassword,
    'invalid_token' => l.errInvalidToken,
    'rate_limited' => l.errRateLimited,
    'email_unavailable' => l.errEmailUnavailable,
    'already_verified' => l.errAlreadyVerified,
    'invalid_input' => l.errInvalidEmail,
    ApiException.network => l.errNetwork,
    _ => l.errUnknown,
  };
}
