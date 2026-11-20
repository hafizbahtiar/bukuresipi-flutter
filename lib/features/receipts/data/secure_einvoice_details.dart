import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/log.dart';
import '../domain/einvoice_details.dart';

/// Keychain / Keystore-backed, like the session tokens: a tax number and an IC number are not for plain prefs.
class SecureEinvoiceDetails implements EinvoiceDetailsStore {
  SecureEinvoiceDetails([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'einvoice_details.$userId';

  @override
  Future<EinvoiceDetails> load(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      return raw == null
          ? const EinvoiceDetails()
          : EinvoiceDetails.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      log('einvoice details: not read ($e)');
      return const EinvoiceDetails();
    }
  }

  @override
  Future<void> save(String userId, EinvoiceDetails details) =>
      _storage.write(key: _key(userId), value: jsonEncode(details.toJson()));
}
