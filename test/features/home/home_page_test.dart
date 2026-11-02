import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/home/presentation/home_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';

import '../../fakes.dart';
import '../shares/presentation/share_intake_test.dart' show FakeShares;

import '../places/places_fixtures.dart';
import '../recipes/recipes_fixtures.dart';

void main() {
  testWidgets('opening home loads the places without notifying during build', (
    t,
  ) async {
    final places = PlacesController(
      FakePlaces()..places = [place(id: 'a', name: 'Kedai Kopi Ah Seng')],
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider(
            create: (_) => RecipesController(FakeRecipes()),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthController(FakeAuthRepository()),
          ),
          ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
          ChangeNotifierProvider(
            create: (_) => RecentShares(FakeShares(), onFinished: () async {}),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: HomePage(),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
  });
}
