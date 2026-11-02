import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/update_gate.dart';
import 'core/router/app_router.dart';
import 'core/settings/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
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
