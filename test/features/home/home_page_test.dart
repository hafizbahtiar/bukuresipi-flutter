import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/home/presentation/home_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
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
import '../shopping/shopping_fixtures.dart';

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
          ChangeNotifierProvider(
            create: (_) => ShoppingController(FakeShopping()),
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
    // Home (the feed) first; the saved places are on Book. Four tabs and "+" in the middle.
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    // "+" opens the add sheet and is not a tab: Home stays selected.
    await t.tap(find.byKey(const ValueKey('nav-add')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('add-receipt')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-link')), findsOneWidget);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await t.tapAt(const Offset(10, 10)); // close the sheet
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Book'));
    await t.pump(); // not settle: Home's location spinner keeps animating (no location plugin in tests)
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
    expect(find.byKey(const ValueKey('book-map')), findsOneWidget);
    // The tabs after "+" are one place to the right in the bar.
    await t.tap(find.text('Account'));
    await t.pump();
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
  });
}
