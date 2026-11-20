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
    expect(find.text('For my lovely wife'), findsOneWidget);
    expect(find.text('OpenFreeMap'), findsOneWidget);
    await t.scrollUntilVisible(find.text('OpenStreetMap contributors'), 200);
    await t.scrollUntilVisible(find.text('Overture Maps'), 200);
    await t.scrollUntilVisible(find.text('Google Fonts'), 200);
    expect(find.text('Google Fonts'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Halal Malaysia directory (JAKIM)'),
      200,
    );
    await t.scrollUntilVisible(find.byKey(const Key('credits-licenses')), 200);
    await t.tap(find.byKey(const Key('credits-licenses')));
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.textContaining('Tri Digital Niaga'), findsWidgets);
  });

  testWidgets('the maker is named at the end', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        locale: Locale('ms'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ms')],
        home: CreditsPage(),
      ),
    );
    await t.scrollUntilVisible(
      find.textContaining('dibangunkan oleh Tri Digital Niaga'),
      300,
    );
    expect(find.textContaining('SSM 202603244841'), findsOneWidget);
  });
}
