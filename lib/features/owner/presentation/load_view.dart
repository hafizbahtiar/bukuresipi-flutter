import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';

/// Owner pages: spinner, then [child], or the error with "Try again". Pull down to reload.
class LoadView extends StatelessWidget {
  const LoadView({
    super.key,
    required this.loading,
    required this.error,
    required this.onReload,
    required this.child,
  });

  final bool loading;
  final Object? error;
  final Future<void> Function() onReload;

  /// Null until the first load finished.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (child == null && loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (child == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error == null ? l.ownerLoadFailed : errorText(l, error!),
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: onReload, child: Text(l.tryAgain)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: onReload, child: child!);
  }
}
