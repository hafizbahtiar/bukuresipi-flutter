import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';

/// The phone's side of a passkey: Android's Credential Manager (MainActivity.kt) shows the fingerprint / screen-lock
/// sheet. The API writes the WebAuthn options and checks the answer (bukuresipi-hono src/features/auth/passkeys.ts);
/// both pass through here untouched. Tests use a fake.
abstract interface class PasskeyAuth {
  /// Makes a passkey for the signed-in user. null = the user closed the sheet.
  /// Throws ApiException: passkey_exists (this phone already has one for the account), passkey_failed.
  Future<Map<String, dynamic>?> create(Map<String, dynamic> options);

  /// Signs with a passkey the phone holds. null = the user closed the sheet.
  /// Throws ApiException: no_passkey (none on this phone), passkey_failed.
  Future<Map<String, dynamic>?> get(Map<String, dynamic> options);
}

class ChannelPasskeyAuth implements PasskeyAuth {
  static const _channel = MethodChannel('bukuresipi/passkey');
  static const _codes = {'passkey_exists', 'no_passkey'};

  /// Android 9+ only; anything else (iOS for now, an old phone) = no passkey buttons.
  static Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _call(
    String method,
    Map<String, dynamic> options,
  ) async {
    try {
      final json = await _channel.invokeMethod<String>(
        method,
        jsonEncode(options),
      );
      return json == null ? null : jsonDecode(json) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      // The exception type only (e.g. "...TYPE_NO_CREDENTIAL"): never the request or the answer.
      log('passkey: $method ${e.code} ${e.message ?? ''}');
      throw ApiException(_codes.contains(e.code) ? e.code : 'passkey_failed');
    }
  }

  @override
  Future<Map<String, dynamic>?> create(Map<String, dynamic> options) =>
      _call('create', options);

  @override
  Future<Map<String, dynamic>?> get(Map<String, dynamic> options) =>
      _call('get', options);
}
