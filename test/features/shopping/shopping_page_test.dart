import 'package:bukuresipi_flutter/features/shopping/domain/shopping.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/pages/shopping_page.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'shopping_fixtures.dart';

void main() {
  late FakeShopping repo;
  late ShoppingController shopping;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: shopping,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: ShoppingPage(),
        ),
      ),
    );
    await shopping.load();
    await t.pumpAndSettle();
  }

  setUp(() {
    repo = FakeShopping();
    shopping = ShoppingController(repo);
  });

  testWidgets('empty list says how to fill it', (t) async {
    await pump(t);
    expect(find.textContaining('Nothing to buy'), findsOneWidget);
  });

  testWidgets(
    'a recipe line shows its recipe and product hints; ticking moves it down and clear removes it',
    (t) async {
      await shopping.addRecipe('r-1');
      await shopping.addText('Sabun');
      await pump(t);
      expect(find.text('For Nasi Lemak Ayam'), findsOneWidget);
      expect(
        find.textContaining(
          'e.g. Beras Super Special Tempatan Jati 5kg (Jati)',
          findRichText: true,
        ),
        findsOneWidget,
      );

      await t.tap(find.text('2 cawan beras putih'));
      await t.pumpAndSettle();
      expect(shopping.items.map((i) => i.text), [
        'Sabun',
        '2 cawan beras putih',
      ]);
      expect(
        find.text('For Nasi Lemak Ayam'),
        findsNothing,
      ); // bought: hints hidden

      await t.tap(find.byTooltip('Clear bought items'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear bought items').last);
      await t.pumpAndSettle();
      expect(shopping.items.map((i) => i.text), ['Sabun']);
    },
  );

  testWidgets('typing an item adds it', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'Gula');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Gula'), findsOneWidget);
    expect(repo.items.single.text, 'Gula');
  });

  testWidgets('a summed line names every recipe it came from', (t) async {
    repo.items = [
      const ShoppingItem(
        id: 'i1',
        text: '3.5 cawan Beras putih',
        done: false,
        recipes: [
          (id: 'r-1', name: 'Nasi Lemak Ayam'),
          (id: 'r-2', name: 'Nasi Goreng'),
        ],
      ),
    ];
    await pump(t);
    expect(find.text('3.5 cawan Beras putih'), findsOneWidget);
    expect(find.text('For Nasi Lemak Ayam, Nasi Goreng'), findsOneWidget);
  });

  testWidgets(
    '"See all" lists every catalogue product of the line\'s ingredient',
    (t) async {
      await shopping.addRecipe('r-1');
      await pump(t);
      await t.tap(find.textContaining('See all'));
      await t.pumpAndSettle();
      expect(find.text('Products: Beras putih'), findsOneWidget);
      expect(
        find.text('Jati Signature Super Special Rice 10kg'),
        findsOneWidget,
      );
      expect(find.text('Jati · Serba Wangi Sdn Bhd'), findsOneWidget);
    },
  );

  testWidgets('typing 2+ letters suggests catalogue names; tapping one adds it', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'g');
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Gula pasir'), findsNothing); // one letter: no lookup
    await t.enterText(find.byType(TextField), 'gula');
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(find.text('Gula melaka'), findsOneWidget);
    await t.tap(find.text('Gula melaka'));
    await t.pumpAndSettle();
    expect(shopping.items.map((i) => i.text), contains('Gula melaka'));
    expect(find.text('Gula pasir'), findsNothing); // suggestions cleared after adding
  });
}
