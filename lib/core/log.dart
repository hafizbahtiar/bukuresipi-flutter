import 'package:flutter/foundation.dart';

/// Debug-build console log (`flutter run`). Release builds print nothing. Never pass tokens or passwords.
void log(String message) {
  if (kDebugMode) debugPrint('[bukuresipi] $message');
}
