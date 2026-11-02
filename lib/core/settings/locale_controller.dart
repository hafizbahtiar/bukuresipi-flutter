import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language: Malay (default) or English. Saved on the device; also sent to the API at register so emails match.
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs);

  final SharedPreferences _prefs;
  static const supported = [Locale('ms'), Locale('en')];
  static const _key = 'lang';

  String get lang => _prefs.getString(_key) == 'en' ? 'en' : 'ms';
  Locale get locale => Locale(lang);

  Future<void> setLang(String lang) async {
    await _prefs.setString(_key, lang == 'en' ? 'en' : 'ms');
    notifyListeners();
  }
}
