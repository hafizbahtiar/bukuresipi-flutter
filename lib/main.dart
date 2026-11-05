// Composition root: the only place that builds concrete classes. Everything below depends on interfaces
// (AuthRepository, TokenStore) handed down through Provider, so tests swap them for fakes.
import 'dart:io';

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
import 'features/family/data/family_repository_impl.dart';
import 'features/family/presentation/family_controller.dart';
import 'features/owner/data/owner_repository_impl.dart';
import 'features/owner/domain/owner_repository.dart';
import 'features/places/data/places_repository_impl.dart';
import 'features/places/presentation/places_controller.dart';
import 'features/push/push_controller.dart';
import 'features/push/push_messaging.dart';
import 'features/recipes/data/recipes_repository_impl.dart';
import 'features/recipes/presentation/recipes_controller.dart';
import 'features/shopping/data/shopping_repository_impl.dart';
import 'features/shopping/presentation/shopping_controller.dart';
import 'features/shares/data/plugin_incoming_shares.dart';
import 'features/shares/data/webview_caption_reader.dart';
import 'features/shares/data/share_repository_impl.dart';
import 'features/shares/domain/share_repository.dart';
import 'features/shares/presentation/recent_shares.dart';
import 'features/shares/presentation/share_intake.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final info = await PackageInfo.fromPlatform();
  final tokens = SecureTokenStore();
  await tokens.load();

  final api = ApiClient(
    baseUrl: Env.apiBaseUrl,
    tokens: tokens,
    appVersion: info.version,
  );
  final AuthRepository authRepo = AuthRepositoryImpl(
    AuthApi(api.dio),
    tokens,
    prefs,
  );
  final auth = AuthController(authRepo);
  final update = UpdateGate();
  api
    ..onSessionEnded = auth.sessionEnded
    ..onUpdateRequired = update.markRequired;
  auth.restore();
  final places = PlacesController(PlacesRepositoryImpl(api.dio));
  final recipes = RecipesController(RecipesRepositoryImpl(api.dio));
  final shopping = ShoppingController(ShoppingRepositoryImpl(api.dio));
  // Joining or leaving changes the book, the recipes and which lists exist.
  final family = FamilyController(
    FamilyRepositoryImpl(api.dio),
    onChanged: () async {
      await Future.wait([places.load(), recipes.load(), shopping.load()]);
    },
  );
  auth.addListener(() {
    if (auth.status == AuthStatus.signedOut) {
      places.clear();
      recipes.clear();
      shopping.clear();
      family.clear();
    }
  });
  final ShareRepository shareRepo = ShareRepositoryImpl(api.dio);
  final recent = RecentShares(
    shareRepo,
    onFinished: () async {
      await places.load();
      await recipes.load();
    },
  );
  auth.addListener(() {
    if (auth.status == AuthStatus.signedOut) recent.clear();
  });
  final shares = ShareIntake(
    PluginIncomingShares(),
    shareRepo,
    auth,
    WebViewCaptionReader(),
  ); // started by the app, once the router exists

  // Android only until iOS has its Firebase file; no Firebase = no pushes, the app checks while open instead.
  PushController? push;
  if (Platform.isAndroid) {
    try {
      push = PushController(
        await FirebasePushMessaging.start(),
        api.dio,
        prefs,
        auth,
      );
    } catch (e) {
      debugPrint('push: Firebase did not start: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        if (push != null)
          ChangeNotifierProvider<PushController>.value(value: push),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: update),
        Provider<ShareRepository>.value(value: shareRepo),
        ChangeNotifierProvider.value(value: shares),
        ChangeNotifierProvider.value(value: places),
        ChangeNotifierProvider.value(value: recipes),
        ChangeNotifierProvider.value(value: shopping),
        ChangeNotifierProvider.value(value: family),
        ChangeNotifierProvider.value(value: recent),
        Provider<OwnerRepository>.value(value: OwnerRepositoryImpl(api.dio)),
        ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
      ],
      child: const BukuresipiApp(),
    ),
  );
}
