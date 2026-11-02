// Build-time settings (envied). Debug/profile builds read .env.dev (local `wrangler dev`), release builds read .env
// (production). Generated: env.g.dart (`dart run build_runner build`, git-ignored).
import 'package:envied/envied.dart';
import 'package:flutter/foundation.dart';

part 'env.g.dart';

@Envied(path: '.env', name: 'EnvProd')
abstract class EnvProd {
  @EnviedField(varName: 'API_BASE_URL')
  static const String apiBaseUrl = _EnvProd.apiBaseUrl;
}

@Envied(path: '.env.dev', name: 'EnvDev')
abstract class EnvDev {
  @EnviedField(varName: 'API_BASE_URL')
  static const String apiBaseUrl = _EnvDev.apiBaseUrl;
}

abstract final class Env {
  /// e.g. https://api.bukuresipi.com (no trailing slash, no /api/v1).
  static String get apiBaseUrl => kReleaseMode ? EnvProd.apiBaseUrl : EnvDev.apiBaseUrl;
}
