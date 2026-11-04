import '../../../core/network/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'password_strength.dart';

/// Same rules as the API (bukuresipi-hono password.ts), checked before sending.
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? emailError(AppLocalizations l, String? v) =>
    _email.hasMatch((v ?? '').trim()) ? null : l.errInvalidEmail;

String? passwordError(AppLocalizations l, String? v) =>
    checkPassword(v ?? '').length ? null : l.errWeakPassword;

/// API error code -> sentence for the user.
String errorText(
  AppLocalizations l,
  Object error, {
  bool changingPassword = false,
}) {
  final code = ApiException.from(error).code;
  return switch (code) {
    'invalid_credentials' =>
      changingPassword ? l.errWrongCurrentPassword : l.errInvalidCredentials,
    'email_taken' => l.errEmailTaken,
    'disposable_email' => l.errDisposableEmail,
    'weak_password' => l.errWeakPassword,
    'invalid_token' => l.errInvalidToken,
    'rate_limited' => l.errRateLimited,
    'email_unavailable' => l.errEmailUnavailable,
    'already_verified' => l.errAlreadyVerified,
    'daily_limit' => l.errReportDailyLimit,
    'not_saved' => l.ratingNotSaved,
    'email_unverified' => l.ratingVerifyEmail,
    'owner_account' => l.errOwnerAccount,
    'invalid_input' => l.errInvalidEmail,
    ApiException.network => l.errNetwork,
    _ => l.errUnknown,
  };
}
