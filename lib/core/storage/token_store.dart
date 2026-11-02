import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory Tokens.fromJson(Map<String, dynamic> json) => Tokens(
    access: json['accessToken'] as String,
    refresh: json['refreshToken'] as String,
  );
}

/// The signed-in session's tokens. Kept in memory after [load] so a request never waits on the keystore.
abstract interface class TokenStore {
  Tokens? get current;
  Future<void> load();
  Future<void> save(Tokens tokens);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-backed encrypted storage (Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  Tokens? _current;
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  @override
  Tokens? get current => _current;

  @override
  Future<void> load() async {
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    _current = access != null && refresh != null
        ? Tokens(access: access, refresh: refresh)
        : null;
  }

  @override
  Future<void> save(Tokens tokens) async {
    _current = tokens;
    await _storage.write(key: _access, value: tokens.access);
    await _storage.write(key: _refresh, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    _current = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

/// For tests and previews.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._current]);

  Tokens? _current;

  @override
  Tokens? get current => _current;
  @override
  Future<void> load() async {}
  @override
  Future<void> save(Tokens tokens) async => _current = tokens;
  @override
  Future<void> clear() async => _current = null;
}
