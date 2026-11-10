import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or the phone's own setting (the default). Saved on the device.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'theme';

  ThemeMode get mode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_key)] ?? ThemeMode.system;

  Future<void> setMode(ThemeMode mode) async {
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }
}
