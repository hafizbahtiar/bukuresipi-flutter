import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/halal_status.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (claim, text) in [
    ('says_halal', 'The post says halal'),
    ('says_not_halal', 'The post says not halal'),
    (null, 'No halal claim found'),
  ]) {
    testWidgets('halal status: $claim -> "$text"', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: Scaffold(body: HalalStatus(claim: claim)),
        ),
      );
      expect(find.text(text), findsOneWidget);
    });
  }
}
