import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keystore that cannot decrypt (e.g. data restored to a new phone without its key).
class _Unreadable extends Fake implements FlutterSecureStorage {
  final deleted = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'BadPaddingException');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => deleted.add(key);
}

void main() {
  test(
    'an unreadable keystore means signed out, not a crash at launch',
    () async {
      final storage = _Unreadable();
      final store = SecureTokenStore(storage);
      await store.load();
      expect(store.current, isNull);
      expect(storage.deleted, containsAll(['access_token', 'refresh_token']));
    },
  );
}
