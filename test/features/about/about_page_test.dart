import 'package:bukuresipi_flutter/features/about/presentation/pages/about_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About: what it is, the halal note, the links and the version', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ms')],
        home: AboutPage(version: '1.4.0 (12)'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Bukuresipi'), findsOneWidget);
    expect(find.textContaining('does not certify'), findsOneWidget);
    for (final label in ['Website', 'Credits', 'Delete my account']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Version 1.4.0 (12)'), findsOneWidget);
  });
}
