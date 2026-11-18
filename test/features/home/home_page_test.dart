import 'package:bukuresipi_flutter/core/settings/locale_controller.dart';
import 'package:bukuresipi_flutter/core/network/update_gate.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/home/presentation/pages/home_page.dart';
import 'package:bukuresipi_flutter/features/home/presentation/widgets/floating_nav.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
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
import '../receipts/receipts_fixtures.dart';
import '../shares/presentation/share_intake_test.dart' show FakeShares;

import '../places/places_fixtures.dart';
import '../recipes/recipes_fixtures.dart';
import '../shopping/shopping_fixtures.dart';

Future<void> pumpHome(WidgetTester t, {Object? open}) async {
  final places = PlacesController(
    FakePlaces()..places = [place(id: 'a', name: 'Kedai Kopi Ah Seng')],
  );
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: places),
        ChangeNotifierProvider(create: (_) => RecipesController(FakeRecipes())),
        ChangeNotifierProvider(
          create: (_) => AuthController(FakeAuthRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ShoppingController(FakeShopping()),
        ),
        Provider<ReceiptsRepository>.value(value: FakeReceipts()),
        ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
        ChangeNotifierProvider(
          create: (_) => UpdateGate(playHasUpdate: () async => false),
        ),
        ChangeNotifierProvider(
          create: (_) => RecentShares(FakeShares(), onFinished: () async {}),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: HomePage(open: open),
      ),
    ),
  );
}

int selectedTab(WidgetTester t) =>
    t.widget<FloatingNav>(find.byType(FloatingNav)).selected;

void main() {
  testWidgets('opening home loads the places without notifying during build', (
    t,
  ) async {
    await pumpHome(t);
    await t.pump();
    expect(t.takeException(), isNull);
    // Home (the feed) first; the saved places are on Book. Four tabs and "+" in the middle.
    for (final name in ['Home', 'Book', 'Receipts', 'Account', 'Add']) {
      expect(
        find.byTooltip(name),
        findsOneWidget,
      ); // icons only: the name is the tooltip
    }
    // "+" opens the add sheet and is not a tab: Home stays selected.
    await t.tap(find.byKey(const ValueKey('nav-add')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('add-receipt')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-link')), findsOneWidget);
    expect(selectedTab(t), 0);
    await t.tapAt(const Offset(10, 10)); // close the sheet
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('nav-tab-1')));
    await t.pump(); // not settle: Home's location spinner keeps animating (no location plugin in tests)
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
    expect(find.byKey(const ValueKey('book-map')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-tab-3')));
    await t.pump();
    expect(selectedTab(t), 3);
  });

  testWidgets(
    'the nav shrinks while a list scrolls either way, and grows back once it has rested',
    (t) async {
      await pumpHome(t, open: HomePage.bookTab);
      await t.pump();
      bool compact() => t.widget<FloatingNav>(find.byType(FloatingNav)).compact;
      final tab = t.element(find.byType(Scrollable).first);
      ScrollMetrics metrics(AxisDirection axis) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 200,
        viewportDimension: 600,
        axisDirection: axis,
        devicePixelRatio: 1,
      );
      Future<void> send(ScrollNotification n) async {
        n.dispatch(tab);
        await t.pump();
      }

      Future<void> start([AxisDirection axis = AxisDirection.down]) =>
          send(ScrollStartNotification(metrics: metrics(axis), context: tab));
      Future<void> scroll(
        double delta, [
        AxisDirection axis = AxisDirection.down,
      ]) => send(
        ScrollUpdateNotification(
          metrics: metrics(axis),
          context: tab,
          scrollDelta: delta,
        ),
      );
      Future<void> stop() => send(
        ScrollEndNotification(
          metrics: metrics(AxisDirection.down),
          context: tab,
        ),
      );

      await start();
      await scroll(10); // a jitter: nothing yet
      expect(compact(), isFalse);
      await scroll(-20); // 30 moved in all, up counts too
      expect(compact(), isTrue);
      await stop();
      await t.pump(const Duration(milliseconds: 300));
      expect(compact(), isTrue); // stopped only a moment: still small
      await start(); // scrolling again cancels the return
      await scroll(40);
      await stop();
      await t.pump(const Duration(milliseconds: 300));
      expect(compact(), isTrue);
      await t.pump(const Duration(milliseconds: 300)); // rested past 0.5 s
      expect(compact(), isFalse);

      await start();
      await scroll(40);
      expect(compact(), isTrue);
      await t.tap(find.byKey(const ValueKey('nav-tab-3'))); // another tab
      await t.pump();
      expect(compact(), isFalse);

      // A card strip scrolled sideways leaves the nav as it is.
      await start(AxisDirection.right);
      await scroll(200, AxisDirection.right);
      expect(compact(), isFalse);
      // Not settle: Home's location spinner never stops in tests. A second lets the spring rest.
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('Done after a share opens Home on the Book tab', (t) async {
    await pumpHome(t, open: HomePage.bookTab);
    await t.pump();
    expect(selectedTab(t), 1);
    expect(find.text('Kedai Kopi Ah Seng'), findsOneWidget);
  });
}
