import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// Owner-only (router guard + the API's requireRole('owner')). Planned tools: docs/plan-pages.md.
class OwnerPage extends StatelessWidget {
  const OwnerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.ownerTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.ownerSoon),
      ),
    );
  }
}
