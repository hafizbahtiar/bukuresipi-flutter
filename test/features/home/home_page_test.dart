import 'package:bukuresipi_flutter/features/home/presentation/home_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../places/places_fixtures.dart';

void main() {
  testWidgets('opening home loads the places without notifying during build', (t) async {
    final places = PlacesController(FakePlaces()..places = [place(id: 'a', name: 'Kedai Kopi Ah Seng')]);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: places,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: [Locale('en'), Locale('ms')],
        home: HomePage(),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
  });
}
