import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../network/update_gate.dart';
import '../open_link.dart';
import '../theme/app_theme.dart';

/// While the session is being restored at launch. Same color as the native splash (pubspec flutter_native_splash),
/// so the hand-over does not flash.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppTheme.pandan,
    body: Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}

/// The app's store page; the Play app opens it (no App Store listing yet, so iOS shows no button).
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.bukuresipi';

/// Updates the app: Google's own update screen (download and restart in the app), else the store page. Used by the
/// Home chip (a newer version is on Play) and the screen below (this version is retired: MIN_APP_VERSION).
Future<void> updateApp(BuildContext context) async {
  final failed = AppLocalizations.of(context).openFailed;
  if (await startPlayUpdate() || !context.mounted) return;
  await openLink(context, playStoreUrl, failed: failed);
}

/// The API answered 426: this app version is retired.
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.system_update_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l.updateTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l.updateText),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('update-store'),
                  icon: const Icon(Icons.shop_outlined),
                  label: Text(l.updateButton),
                  onPressed: () => updateApp(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
