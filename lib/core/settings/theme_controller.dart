import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light (the default), dark, or the phone's own setting. Saved on the device: a choice made before stays.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'theme';

  ThemeMode get mode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_key)] ?? ThemeMode.light;

  Future<void> setMode(ThemeMode mode) async {
    // The cache takes the value at once (mode reads it): switch now, the disk write finishes behind.
    final saved = _prefs.setString(_key, mode.name);
    notifyListeners();
    await saved;
  }
}
