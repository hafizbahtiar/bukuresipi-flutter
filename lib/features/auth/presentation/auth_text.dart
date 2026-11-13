import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'password_strength.dart';

/// Same rules as the API (bukuresipi-hono password.ts), checked before sending.
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? emailError(AppLocalizations l, String? v) =>
    _email.hasMatch((v ?? '').trim()) ? null : l.errInvalidEmail;

String? passwordError(AppLocalizations l, String? v) =>
    checkPassword(v ?? '').length ? null : l.errWeakPassword;

/// A refused sign-in: suspended until a date (or for good), and the owner's reason when given.
String _banned(AppLocalizations l, Map<String, dynamic> data) {
  final until = switch (data['until']) {
    final String s => DateTime.tryParse(s)?.toLocal(),
    _ => null,
  };
  final reason = (data['reason'] as String?)?.trim();
  return [
    until == null
        ? l.errBannedForGood
        : l.errBannedUntil(DateFormat.yMMMd(l.localeName).format(until)),
    if (reason != null && reason.isNotEmpty) l.errBannedReason(reason),
  ].join('\n');
}

/// API error code -> sentence for the user.
String errorText(
  AppLocalizations l,
  Object error, {
  bool changingPassword = false,
}) {
  final e = ApiException.from(error);
  final code = e.code;
  return switch (code) {
    'banned' => _banned(l, e.data),
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
    'list_full' => l.errShoppingListFull,
    'not_maps_link' => l.errNotMapsLink,
    'source_off' => l.errSourceOff,
    'branch_label_taken' => l.errBranchLabelTaken,
    'duplicate_receipt' => l.errDuplicateReceipt,
    'receipt_limit' => l.errReceiptLimit,
    'place_required' => l.errPlaceRequired,
    'not_ready' => l.errReceiptNotReady,
    'no_pin' => l.errMapsNoPin,
    'already_in_family' => l.errAlreadyInFamily,
    'family_full' => l.errFamilyFull,
    'google_email_unverified' => l.errGoogleEmailUnverified,
    'google_account_mismatch' => l.errGoogleAccountMismatch,
    'google_unavailable' => l.errGoogleUnavailable,
    'google_failed' => l.errGoogleFailed,
    'passkey_unavailable' => l.errPasskeyUnavailable,
    'passkey_limit' => l.errPasskeyLimit,
    'invalid_passkey' || 'passkey_failed' => l.errPasskeyFailed,
    'no_passkey' => l.errNoPasskey,
    'passkey_exists' => l.errPasskeyExists,
    'already_linked' => l.errAlreadyLinked,
    'google_in_use' => l.errGoogleInUse,
    'password_required' => l.errPasswordRequired,
    'invite_expired' => l.errInviteExpired,
    'not_in_family' => l.errNotInFamily,
    'not_owner' => l.errNotOwner,
    'invalid_input' => l.errInvalidEmail,
    ApiException.network => l.errNetwork,
    _ => l.errUnknown,
  };
}
