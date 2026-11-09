import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart' show cacheImageFolderName;
import 'package:path_provider/path_provider.dart';

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
  Future<User> setAvatar(String path) => apiCall(
    () async =>
        _remember((await _api.setAvatar(path))['user'] as Map<String, dynamic>),
  );

  @override
  Future<User> removeAvatar() => apiCall(
    () async =>
        _remember((await _api.removeAvatar())['user'] as Map<String, dynamic>),
  );

  // Keyed by user + avatar id: a new upload is a new key, so nothing stale is shown.
  final _avatars = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> avatar(String userId, String avatar) {
    if (_avatars.length >= 40) _avatars.remove(_avatars.keys.first);
    final key = '$userId/$avatar';
    return _avatars[key] ??= _cachedAvatar(userId, avatar)
      ..catchError((Object _) {
        _avatars.remove(key);
        return null;
      });
  }

  /// From extended_image's disk cache folder (its clearDiskCachedImages() empties it too), else downloaded
  /// through Dio and kept there: the request needs the token, which Dio refreshes; a plain network image can't.
  /// A new picture has a new id, so a cached file is never stale.
  Future<Uint8List?> _cachedAvatar(String userId, String avatar) async {
    final file = await _avatarFile(avatar);
    if (file != null && await file.exists()) {
      try {
        return await file.readAsBytes();
      } catch (_) {} // unreadable: download it again
    }
    final bytes = await apiCall(() => _api.avatar(userId));
    if (bytes != null && file != null) {
      unawaited(
        file
            .create(recursive: true)
            .then((f) => f.writeAsBytes(bytes))
            .then((_) {}, onError: (Object _) {}),
      );
    }
    return bytes;
  }

  static final _avatarId = RegExp(r'^[0-9a-fA-F-]{1,64}$');

  /// null = no disk (tests, web) or not an id the server gives (never a path out of the folder).
  Future<File?> _avatarFile(String avatar) async {
    if (!_avatarId.hasMatch(avatar)) return null;
    try {
      final dir = await getTemporaryDirectory();
      return File('${dir.path}/$cacheImageFolderName/avatar-$avatar');
    } catch (_) {
      return null;
    }
  }

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
  Future<User> loginWithGoogle(String idToken, String lang) =>
      apiCall(() async => _signedIn(await _api.google(idToken, lang)));

  @override
  Future<User> linkGoogle(String idToken) => apiCall(
    () async => _remember(
      (await _api.linkGoogle(idToken))['user'] as Map<String, dynamic>,
    ),
  );

  @override
  Future<User> unlinkGoogle() => apiCall(
    () async =>
        _remember((await _api.unlinkGoogle())['user'] as Map<String, dynamic>),
  );

  @override
  Future<void> deleteAccountWithGoogle(String idToken) async {
    await apiCall(() => _api.deleteAccountWithGoogle(idToken));
    await clearLocal();
  }

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
  hasPassword:
      j['hasPassword'] as bool? ??
      true, // a cached user from before Google sign-in
  google: j['google'] as bool? ?? false,
  avatar: j['avatar'] as String?,
);
