import 'user.dart';

/// What the auth screens need. Implemented by data/auth_repository_impl.dart; tests use a fake.
/// Every method throws ApiException (core/network) on failure.
abstract interface class AuthRepository {
  /// A session (tokens) is stored on this device.
  bool get hasSession;

  /// The user from the last successful call, kept on the device so the app opens signed in while offline.
  User? get cachedUser;

  Future<User> me();
  Future<User> login(String email, String password);
  Future<User> register({required String email, required String password, String? name, required String lang});

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
}
