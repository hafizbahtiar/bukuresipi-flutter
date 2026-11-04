import 'package:bukuresipi_flutter/core/widgets/notebook.dart';
import 'package:bukuresipi_flutter/features/credits/presentation/pages/credits_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('credits are grouped on a notebook page', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ms')],
        home: CreditsPage(),
      ),
    );

    expect(find.byType(NotebookPage), findsOneWidget);
    expect(find.byType(NotebookTitle), findsOneWidget);
    expect(find.byType(NotebookRow), findsWidgets);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('OpenFreeMap'), findsOneWidget);
    expect(find.text('OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Overture Maps'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Google Fonts'), 200);
    expect(find.text('Google Fonts'), findsOneWidget);
  });
}
