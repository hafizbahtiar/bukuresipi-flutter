import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug-build console log (`flutter run`). Release builds print nothing. Never pass tokens or passwords.
void log(String message) {
  if (kDebugMode) debugPrint('[bukuresipi] $message');
}

/// A length-capped JSON for a debug log (one bad API row). Never pass tokens or passwords.
String logJson(Object? value, {int max = 1200}) {
  final text = jsonEncode(value);
  return text.length <= max ? text : '${text.substring(0, max)}…';
}
