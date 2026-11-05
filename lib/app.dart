import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/update_gate.dart';
import 'core/router/app_router.dart';
import 'core/settings/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/places/presentation/places_controller.dart';
import 'features/push/push_controller.dart';
import 'features/recipes/presentation/recipes_controller.dart';
import 'features/shares/domain/share_repository.dart';
import 'features/shares/presentation/recent_shares.dart';
import 'features/shares/presentation/share_intake.dart';
import 'l10n/gen/app_localizations.dart';

class BukuresipiApp extends StatefulWidget {
  const BukuresipiApp({super.key});

  @override
  State<BukuresipiApp> createState() => _BukuresipiAppState();
}

class _BukuresipiAppState extends State<BukuresipiApp> {
  late final GoRouter _router = buildRouter(
    context.read<AuthController>(),
    context.read<UpdateGate>(),
  );

  @override
  void initState() {
    super.initState();
    // Shares can arrive before the first frame (app opened from the share sheet): start once the router exists.
    final shares = context.read<ShareIntake>();
    shares.onShow = () => _router.go('/share');
    shares.start();
    final push = context.read<PushController?>();
    if (push != null) {
      push
        ..onForeground = _reload
        ..onTap = _openShare
        ..start();
    }
  }

  void _reload() {
    context.read<RecentShares>().load();
    context.read<PlacesController>().load();
    context.read<RecipesController>().load();
  }

  /// A tapped "share ready" push: the recipe or place it saved, else the book (it shows failed shares).
  Future<void> _openShare(String shareId) async {
    final places = context.read<PlacesController>();
    final shares = context.read<ShareRepository>();
    context.read<RecentShares>().load();
    context.read<RecipesController>().load(); // places load below, awaited
    try {
      final share = await shares.get(shareId);
      if (share.recipeId case final id?) return _router.go('/recipes/$id');
      if (share.restaurantId case final restaurantId?) {
        await places.load();
        final place = places.places
            .where((p) => p.restaurant.id == restaurantId)
            .firstOrNull;
        if (place != null) return _router.go('/places/${place.id}');
      }
    } catch (_) {
      // Signed out, offline or gone: the book is the right place anyway.
    }
    _router.go('/');
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Bukuresipi',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: context.watch<LocaleController>().locale,
    supportedLocales: LocaleController.supported,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router,
  );
}
