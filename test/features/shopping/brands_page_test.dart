import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/pages/brands_page.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../fakes.dart';
import 'shopping_fixtures.dart';

void main() {
  testWidgets(
    'Malaysian brands first is saved on the account and the list is read again',
    (t) async {
      final auth = FakeAuthRepository()
        ..session = true
        ..meResult = testUser;
      final controller = AuthController(auth);
      await controller.restore();
      final shoppingRepo = FakeShopping();
      final shopping = ShoppingController(shoppingRepo);
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: controller),
            ChangeNotifierProvider.value(value: shopping),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BrandsPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('brands-local-first'));
      expect(t.widget<Switch>(toggle).value, isFalse);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(auth.localFirsts, [true]);
      expect(t.widget<Switch>(toggle).value, isTrue);
      expect(controller.user!.localFirst, isTrue);
    },
  );

  testWidgets('lists my brands and what I avoid; a remove takes it off', (
    t,
  ) async {
    final controller = AuthController(
      FakeAuthRepository()
        ..session = true
        ..meResult = testUser,
    );
    await controller.restore();
    final repo = FakeShopping()
      ..choices = (
        mine: const [(ingredient: 'Beras putih', brand: 'Jati')],
        avoid: const [(brand: null, maker: 'Syarikat X')],
      );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: ShoppingController(repo)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrandsPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Jati'), findsOneWidget);
    expect(find.text('Everything this maker makes'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('brands-unavoid-Syarikat X')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('brands-mine-remove-Beras putih')));
    await t.pumpAndSettle();
    expect(repo.brandCalls, ['unavoid Syarikat X', 'clear Beras putih']);
    expect(find.textContaining('None yet'), findsOneWidget);
  });

  testWidgets(
    'Choose a brand: find the ingredient, pick its brand, back on the page with it listed',
    (t) async {
      final controller = AuthController(
        FakeAuthRepository()
          ..session = true
          ..meResult = testUser,
      );
      await controller.restore();
      final repo = FakeShopping()..suggestions = const ['Beras putih'];
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: controller),
            ChangeNotifierProvider.value(value: ShoppingController(repo)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BrandsPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('brands-add')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('brands-add-query')),
        'beras',
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('brands-add-Beras putih')));
      await t.pumpAndSettle();
      expect(find.text('Products: Beras putih'), findsOneWidget);
      await t.tap(
        find.byKey(
          const ValueKey('product-Beras Super Special Tempatan Jati 5kg'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('brand-mine')));
      await t.pumpAndSettle();
      expect(repo.brandCalls, ['mine Beras putih Jati']);
      // Back to the brands' list, still in the sheet; the page behind lists it.
      expect(find.text('Products: Beras putih'), findsOneWidget);
      await t.tapAt(const Offset(10, 10)); // close the sheet
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('brands-mine-Beras putih')),
        findsOneWidget,
      );
    },
  );
}
