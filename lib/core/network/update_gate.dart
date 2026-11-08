import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// The app's update state. [required]: the API answered 426 (this version is retired; the router shows the update
/// screen). [available]: Google Play has a newer version (Home shows an "Update" chip); optional.
class UpdateGate extends ChangeNotifier {
  UpdateGate({Future<bool> Function()? playHasUpdate})
    : _playHasUpdate = playHasUpdate ?? _askPlay;

  final Future<bool> Function() _playHasUpdate;

  bool _required = false;
  bool get required => _required;

  bool _available = false;
  bool get available => _available;

  void markRequired() {
    if (_required) return;
    _required = true;
    notifyListeners();
  }

  /// Asks Google Play once (at start-up). Any failure = no chip: a debug build or a sideloaded APK has no Play
  /// listing, and iOS has no store page yet.
  Future<void> check() async {
    bool yes;
    try {
      yes = await _playHasUpdate();
    } catch (_) {
      yes = false;
    }
    if (yes == _available) return;
    _available = yes;
    notifyListeners();
  }

  static Future<bool> _askPlay() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable;
  }
}

/// Google's own update screen (download + restart in the app); false = not possible here, open the store instead.
Future<bool> startPlayUpdate() async {
  try {
    return await InAppUpdate.performImmediateUpdate() ==
        AppUpdateResult.success;
  } catch (_) {
    return false;
  }
}
