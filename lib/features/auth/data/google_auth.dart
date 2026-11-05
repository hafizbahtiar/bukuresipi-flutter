import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/log.dart';

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
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      // clientConfigurationError here = the Android OAuth client (package + SHA-1) is missing in Google Cloud.
      log('google: ${e.code.name} ${e.description ?? ''}');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}
