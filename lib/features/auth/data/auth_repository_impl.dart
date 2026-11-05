import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens, this._prefs);

  final AuthApi _api;
  final TokenStore _tokens;
  final SharedPreferences _prefs;
  static const _userKey = 'user';

  @override
  bool get hasSession => _tokens.current != null;

  @override
  User? get cachedUser {
    final raw = _prefs.getString(_userKey);
    return raw == null
        ? null
        : userFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<User> _signedIn(Map<String, dynamic> body) async {
    await _tokens.save(Tokens.fromJson(body));
    return _remember(body['user'] as Map<String, dynamic>);
  }

  Future<User> _remember(Map<String, dynamic> json) async {
    await _prefs.setString(_userKey, jsonEncode(json));
    return userFromJson(json);
  }

  @override
  Future<User> me() => apiCall(
    () async => _remember((await _api.me())['user'] as Map<String, dynamic>),
  );

  @override
  Future<User> setName(String name) => apiCall(
    () async =>
        _remember((await _api.setName(name))['user'] as Map<String, dynamic>),
  );

  @override
  Future<User> login(String email, String password) =>
      apiCall(() async => _signedIn(await _api.login(email.trim(), password)));

  @override
  Future<User> register({
    required String email,
    required String password,
    String? name,
    required String lang,
  }) => apiCall(
    () async => _signedIn(
      await _api.register({
        'email': email.trim(),
        'password': password,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'lang': lang,
      }),
    ),
  );

  @override
  Future<void> logout() async {
    final refresh = _tokens.current?.refresh;
    try {
      if (refresh != null) await _api.logout(refresh);
    } catch (_) {
      // Offline or already ended: signing out on this device still happens.
    }
    await clearLocal();
  }

  @override
  Future<void> clearLocal() async {
    await _tokens.clear();
    await _prefs.remove(_userKey);
  }

  @override
  Future<void> verifyEmail(String token) =>
      apiCall(() => _api.verifyEmail(token));

  @override
  Future<void> resendVerification() => apiCall(_api.resendVerification);

  @override
  Future<void> forgotPassword(String email) =>
      apiCall(() => _api.forgotPassword(email.trim()));

  @override
  Future<void> resetPassword(String token, String password) =>
      apiCall(() => _api.resetPassword(token, password));

  @override
  Future<void> changePassword(String current, String next) => apiCall(
    () async =>
        _tokens.save(Tokens.fromJson(await _api.changePassword(current, next))),
  );

  @override
  Future<void> changeEmail(String email, String password) =>
      apiCall(() => _api.changeEmail(email, password));

  @override
  Future<void> deleteAccount(String email, String password) async {
    await apiCall(() => _api.deleteAccount(email, password));
    await clearLocal();
  }
}

User userFromJson(Map<String, dynamic> j) => User(
  id: j['id'] as String,
  email: j['email'] as String,
  name: j['name'] as String?,
  role: j['role'] as String,
  lang: j['lang'] as String,
  emailVerified: j['emailVerified'] as bool,
);
