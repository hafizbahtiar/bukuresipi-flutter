import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/meal_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../receipts_fixtures.dart';

const MealItem nasi = (
  name: 'Nasi Lemak',
  eaten: 1,
  kcal: 480,
  kcalSource: 'ai',
  carbsG: 60,
  proteinG: 12,
  fatG: 21,
);
const MealItem teh = (
  name: 'Teh Tarik',
  eaten: 1,
  kcal: 125,
  kcalSource: 'table',
  carbsG: 20,
  proteinG: 4,
  fatG: 3,
);

Future<void> pump(WidgetTester t, FakeReceipts repo, {DayMeal? meal}) async {
  // A phone-tall screen: the total sits below the photo and the dishes.
  t.view.physicalSize = const Size(400, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Provider<ReceiptsRepository>.value(
      value: repo,
      child: MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: meal == null
            ? const MealPage(path: '/no/such/photo.jpg')
            : MealPage(meal: meal),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'the estimate lists each dish; servings, removal and the total follow; Save sends the dishes',
    (t) async {
      final repo = FakeReceipts()..estimate = const [nasi, teh];
      await pump(t, repo);
      expect(repo.estimated, ['/no/such/photo.jpg']);
      expect(find.text('Total 605 kcal'), findsOneWidget);
      expect(find.text('Carbs 80 g · Protein 16 g · Fat 24 g'), findsOneWidget);

      await t.tap(find.byIcon(Icons.add_circle_outline).first);
      await t.pumpAndSettle();
      expect(find.text('1.5 serving(s)'), findsOneWidget);
      expect(find.text('720 kcal'), findsOneWidget);

      await t.tap(find.byTooltip('Remove').last);
      await t.pumpAndSettle();
      expect(find.text('Total 720 kcal'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('meal-save')));
      await t.pumpAndSettle();
      expect(repo.savedMeals.single.map((i) => (i.name, i.eaten)), [
        ('Nasi Lemak', 1.5),
      ]);
    },
  );

  testWidgets('a renamed dish waits for the server\'s numbers', (t) async {
    final repo = FakeReceipts()..estimate = const [nasi];
    await pump(t, repo);
    await t.enterText(find.byType(TextFormField), 'Nasi Kerabu');
    await t.pumpAndSettle();
    expect(find.text('kcal after saving'), findsOneWidget);
    expect(find.textContaining('Carbs'), findsNothing);
  });

  testWidgets('a refusal is shown with a retry', (t) async {
    final repo = FakeReceipts()
      ..estimateError = const ApiException('not_food', status: 422);
    await pump(t, repo);
    expect(
      find.text('No food found in that photo. Try another one.'),
      findsOneWidget,
    );
    repo
      ..estimateError = null
      ..estimate = const [teh];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Total 125 kcal'), findsOneWidget);
  });

  testWidgets('a quarter serving reads 0.25, not 0.3', (t) async {
    final repo = FakeReceipts()
      ..estimate = const [
        (
          name: 'Sambal',
          eaten: 0.25,
          kcal: 80,
          kcalSource: 'ai',
          carbsG: null,
          proteinG: null,
          fatG: null,
        ),
      ];
    await pump(t, repo);
    expect(find.text('0.25 serving(s)'), findsOneWidget);
    expect(find.text('20 kcal'), findsOneWidget);
  });

  testWidgets(
    'a saved meal opens without a photo or an estimate; Save replaces it at its time',
    (t) async {
      final repo = FakeReceipts();
      final at = DateTime(2026, 11, 10, 13, 30);
      await pump(
        t,
        repo,
        meal: (
          id: 'm-1',
          eatenAt: at,
          eatenKcal: 125,
          macros: null,
          items: const [teh],
        ),
      );
      expect(repo.estimated, isEmpty);
      expect(find.byType(Image), findsNothing);
      expect(find.text('1:30 PM'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_circle_outline));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('meal-save')));
      await t.pumpAndSettle();
      final (id, eatenAt, items) = repo.replacedMeals.single;
      expect((id, eatenAt, items.single.eaten), ('m-1', at, 1.5));
    },
  );
}
