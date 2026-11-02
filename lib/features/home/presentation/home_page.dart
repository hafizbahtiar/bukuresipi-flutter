import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';

/// Placeholder until the shares / recipes / map features (docs/plan-pages.md).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [IconButton(tooltip: l.accountTitle, icon: const Icon(Icons.person_outline), onPressed: () => context.push('/account'))],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.homeEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
