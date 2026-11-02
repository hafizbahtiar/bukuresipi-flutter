// Composition root: the only place that builds concrete classes. Everything below depends on interfaces
// (AuthRepository, TokenStore) handed down through Provider, so tests swap them for fakes.
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/env/env.dart';
import 'core/network/api_client.dart';
import 'core/network/update_gate.dart';
import 'core/settings/locale_controller.dart';
import 'core/storage/token_store.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final info = await PackageInfo.fromPlatform();
  final tokens = SecureTokenStore();
  await tokens.load();

  final api = ApiClient(baseUrl: Env.apiBaseUrl, tokens: tokens, appVersion: info.version);
  final AuthRepository authRepo = AuthRepositoryImpl(AuthApi(api.dio), tokens, prefs);
  final auth = AuthController(authRepo);
  final update = UpdateGate();
  api
    ..onSessionEnded = auth.sessionEnded
    ..onUpdateRequired = update.markRequired;
  auth.restore();

  runApp(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: update),
      ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
    ],
    child: const BukuresipiApp(),
  ));
}
