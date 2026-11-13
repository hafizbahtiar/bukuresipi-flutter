import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/passkey_auth.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Session state for the whole app (the router listens to it). Actions throw ApiException; screens show the code.
class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;
  AuthStatus _status = AuthStatus.unknown;
  User? _user;

  AuthStatus get status => _status;
  User? get user => _user;

  void _set(AuthStatus status, User? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }

  /// At launch: open signed in from the saved user at once, then confirm with the API.
  Future<void> restore() async {
    if (!_repo.hasSession) return _set(AuthStatus.signedOut, null);
    final cached = _repo.cachedUser;
    if (cached != null) _set(AuthStatus.signedIn, cached);
    try {
      _set(AuthStatus.signedIn, await _repo.me());
    } on ApiException catch (e) {
      if (e.status == 401) {
        await _repo.clearLocal();
        _set(AuthStatus.signedOut, null);
      } else if (cached == null) {
        _set(
          AuthStatus.signedOut,
          null,
        ); // offline with nothing saved: sign in again later
      }
    }
  }

  Future<void> login(String email, String password) async =>
      _set(AuthStatus.signedIn, await _repo.login(email, password));

  Future<void> register({
    required String email,
    required String password,
    String? name,
    required String lang,
  }) async => _set(
    AuthStatus.signedIn,
    await _repo.register(
      email: email,
      password: password,
      name: name,
      lang: lang,
    ),
  );

  Future<void> logout() async {
    await _repo.logout();
    _set(AuthStatus.signedOut, null);
  }

  /// The API ended the session (refresh rejected, or a password reset). Tokens are already gone or about to be.
  Future<void> sessionEnded() async {
    await _repo.clearLocal();
    if (_status != AuthStatus.signedOut) _set(AuthStatus.signedOut, null);
  }

  /// Throws ApiException (invalid_input for a name with no letter or over 40 characters).
  Future<void> setName(String name) async =>
      _set(AuthStatus.signedIn, await _repo.setName(name));

  /// Throws ApiException (invalid_input outside 500-10,000).
  Future<void> setKcalTarget(int? kcal) async =>
      _set(AuthStatus.signedIn, await _repo.setKcalTarget(kcal));

  Future<void> setAvatar(String path) async =>
      _set(AuthStatus.signedIn, await _repo.setAvatar(path));

  Future<void> removeAvatar() async =>
      _set(AuthStatus.signedIn, await _repo.removeAvatar());

  Future<Uint8List?> avatar(String userId, String avatar) =>
      _repo.avatar(userId, avatar);

  Future<void> refreshUser() async {
    if (_status == AuthStatus.signedIn) {
      _set(AuthStatus.signedIn, await _repo.me());
    }
  }

  Future<void> verifyEmail(String token) async {
    await _repo.verifyEmail(token);
    // Verified already (the link is spent): a failed profile refresh must not turn that into an error.
    if (_status == AuthStatus.signedIn) {
      await refreshUser().catchError((Object _) {});
    }
  }

  Future<void> resendVerification() async {
    try {
      await _repo.resendVerification();
    } on ApiException catch (e) {
      if (e.code == 'already_verified') await refreshUser();
      rethrow;
    }
  }

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email);

  /// The API ends every session on reset, including this device's.
  Future<void> resetPassword(String token, String password) async {
    await _repo.resetPassword(token, password);
    await sessionEnded();
  }

  Future<void> loginWithGoogle(String idToken, String lang) async =>
      _set(AuthStatus.signedIn, await _repo.loginWithGoogle(idToken, lang));

  /// The phone shows its passkey sheet for the API's challenge. false = the user closed it.
  Future<bool> loginWithPasskey(PasskeyAuth passkeys) async {
    final response = await passkeys.get(await _repo.passkeyLoginOptions());
    if (response == null) return false;
    _set(AuthStatus.signedIn, await _repo.loginWithPasskey(response));
    return true;
  }

  Future<void> linkGoogle(String idToken) async =>
      _set(AuthStatus.signedIn, await _repo.linkGoogle(idToken));

  Future<void> unlinkGoogle() async =>
      _set(AuthStatus.signedIn, await _repo.unlinkGoogle());

  Future<void> deleteAccountWithGoogle(String idToken) async {
    await _repo.deleteAccountWithGoogle(idToken);
    if (_status != AuthStatus.signedOut) _set(AuthStatus.signedOut, null);
  }

  /// Throws ApiException (wrong password, owner account). Works signed out too: the website's link opens this page.
  Future<void> deleteAccount(String email, String password) async {
    await _repo.deleteAccount(email, password);
    if (_status != AuthStatus.signedOut) _set(AuthStatus.signedOut, null);
  }

  Future<void> changePassword(String current, String next) =>
      _repo.changePassword(current, next);

  /// Throws ApiException. The user's email updates when the link is opened (verifyEmail refreshes the user).
  Future<void> changeEmail(String email, String password) =>
      _repo.changeEmail(email, password);
}
