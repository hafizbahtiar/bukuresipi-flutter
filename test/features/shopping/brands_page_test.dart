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
      expect(t.widget<SwitchListTile>(toggle).value, isFalse);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(auth.localFirsts, [true]);
      expect(t.widget<SwitchListTile>(toggle).value, isTrue);
      expect(controller.user!.localFirst, isTrue);
    },
  );
}
