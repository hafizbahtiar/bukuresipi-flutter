// Build-time settings (envied) from .env (git-ignored; template .env.example). Generated: env.g.dart
// (`dart run build_runner build`, git-ignored). Every build talks to the production API for now.
// shortcut: no local-API build; add a .env.dev + `kReleaseMode` switch (or flavors) when testing against wrangler dev.
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract final class Env {
  /// e.g. https://api.bukuresipi.com (no trailing slash, no /api/v1).
  @EnviedField(varName: 'API_BASE_URL')
  static const String apiBaseUrl = _Env.apiBaseUrl;

  /// The WEB OAuth client id (bukuresipi-hono docs/google-signin-setup.md). Missing = no Google button.
  @EnviedField(varName: 'GOOGLE_SERVER_CLIENT_ID', optional: true)
  static const String? googleServerClientId = _Env.googleServerClientId;
}
