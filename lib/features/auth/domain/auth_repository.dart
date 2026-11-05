import 'user.dart';

/// What the auth screens need. Implemented by data/auth_repository_impl.dart; tests use a fake.
/// Every method throws ApiException (core/network) on failure.
abstract interface class AuthRepository {
  /// A session (tokens) is stored on this device.
  bool get hasSession;

  /// The user from the last successful call, kept on the device so the app opens signed in while offline.
  User? get cachedUser;

  Future<User> me();

  /// The display name other users see (family, a public recipe's credit); never the email.
  Future<User> setName(String name);
  Future<User> login(String email, String password);
  Future<User> register({
    required String email,
    required String password,
    String? name,
    required String lang,
  });

  /// Signs in (or up) with a Google ID token; the API links or creates the account.
  Future<User> loginWithGoogle(String idToken, String lang);

  /// Account > Google. Unlink needs a password (409 password_required otherwise).
  Future<User> linkGoogle(String idToken);
  Future<User> unlinkGoogle();

  /// Deletes a Google-only account (it has no password): a fresh Google ID token is the proof.
  Future<void> deleteAccountWithGoogle(String idToken);

  /// Ends this device's session on the server (best effort) and always locally.
  Future<void> logout();

  /// Forget the session locally only (the server already ended it).
  Future<void> clearLocal();

  Future<void> verifyEmail(String token);
  Future<void> resendVerification();
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String password);

  /// Ends every other session; this device gets new tokens.
  Future<void> changePassword(String current, String next);

  /// Emails a confirmation link to [email]; the account email changes when it is opened.
  Future<void> changeEmail(String email, String password);

  /// Deletes the account for good (email + password confirm it), then forgets it on this device.
  Future<void> deleteAccount(String email, String password);
}
