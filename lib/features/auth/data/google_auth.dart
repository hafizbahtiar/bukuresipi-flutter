import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';

/// Asks Google (the Android account sheet) for an ID token; the API checks it (bukuresipi-hono src/features/auth/google.ts).
/// Tests use a fake.
abstract interface class GoogleAuth {
  /// null = the user closed the sheet. Throws when Google sign-in is not set up (see docs/google-signin-setup.md).
  Future<String?> idToken();

  /// After our sign-out: the next sign-in shows the account sheet again instead of picking the last account.
  Future<void> signOut();
}

class PluginGoogleAuth implements GoogleAuth {
  PluginGoogleAuth(this._serverClientId);

  /// The WEB OAuth client id: Google issues the ID token for it, and the API accepts that audience.
  final String _serverClientId;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= GoogleSignIn.instance.initialize(
    serverClientId: _serverClientId,
  );

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
      final token = account.authentication.idToken;
      log(
        'google: account picked, ${token == null ? 'NO id token' : 'id token received'}',
      );
      if (token == null) throw const ApiException('google_failed');
      return token;
    } on GoogleSignInException catch (e) {
      // Logged every time (never the token): Credential Manager reports a missing/mismatched Android OAuth client
      // (package + SHA-1) as "canceled" too, right after the account is picked, e.g. "[16] Account reauth failed".
      log('google: ${e.code.name} ${e.description ?? ''}');
      if (_closedByUser(e)) return null;
      throw const ApiException('google_failed');
    }
  }

  /// Only a real "closed the sheet" stays silent; any other cancel is a setup problem the user should hear about.
  static bool _closedByUser(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.interrupted) return true;
    if (e.code != GoogleSignInExceptionCode.canceled) return false;
    final d = (e.description ?? '').toLowerCase();
    return d.isEmpty || d.contains('by the user') || d.contains('user cancel');
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}
