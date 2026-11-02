import 'package:flutter/foundation.dart';

/// Becomes true once the API answers 426 (this app version is too old); the router then shows the update screen.
class UpdateGate extends ChangeNotifier {
  bool _required = false;
  bool get required => _required;

  void markRequired() {
    if (_required) return;
    _required = true;
    notifyListeners();
  }
}
