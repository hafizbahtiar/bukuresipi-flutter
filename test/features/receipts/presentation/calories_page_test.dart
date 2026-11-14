import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';
import 'package:bukuresipi_flutter/features/receipts/presentation/pages/calories_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../receipts_fixtures.dart';

void main() {
  Future<void> pump(
    WidgetTester t,
    FakeReceipts repo, {
    FakeAuthRepository? auth,
  }) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReceiptsRepository>.value(value: repo),
          ChangeNotifierProvider(
            create: (_) => AuthController(auth ?? FakeAuthRepository()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CustomScrollView(slivers: [CaloriesSection()])),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  DailyCalories day({
    int eaten = 0,
    int? target,
    bool estimate = false,
    double unknown = 0,
    List<DayReceipt> receipts = const [],
    List<DayMeal> meals = const [],
    Macros? macros,
  }) => (
    eatenKcal: eaten,
    target: target,
    hasEstimate: estimate,
    unknownEaten: unknown,
    macros: macros,
    receipts: receipts,
    meals: meals,
  );

  CalorieDays days({int? target, int count = 30}) => CalorieDays(
    days: [
      for (var i = 0; i < count; i++)
        (
          date: DateTime(2026, 10, 12 + i),
          eatenKcal: i == count - 1 ? 900 : 100 + i,
          hasEstimate: false,
          unknownEaten: 0.0,
        ),
    ],
    target: target,
  );

  testWidgets('today against the target; the target is set from here', (
    t,
  ) async {
    final repo = FakeReceipts()
      ..today = day(eaten: 900, estimate: true)
      ..calorieDaysAnswer = days();
    final auth = FakeAuthRepository();
    await pump(t, repo, auth: auth);
    expect(find.text('900 kcal'), findsOneWidget);
    repo.today = day(eaten: 900, target: 2000, estimate: true);
    repo.calorieDaysAnswer = days(target: 2000);
    await t.tap(find.text('Set a daily target'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('kcal-target')), '2000');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(auth.kcalTargets, [2000]);
    expect(find.text('900 / 2000 kcal'), findsOneWidget);
    expect(find.text('Change target'), findsOneWidget);
  });

  testWidgets('a target outside 500-10,000 is not sent', (t) async {
    final auth = FakeAuthRepository();
    await pump(t, FakeReceipts(), auth: auth);
    await t.tap(find.text('Set a daily target'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('kcal-target')), '50');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(auth.kcalTargets, isEmpty);
  });

  testWidgets('the chart shows the range; 7 / 30 asks again', (t) async {
    final repo = FakeReceipts()
      ..today = day(eaten: 900, target: 2000)
      ..calorieDaysAnswer = days(target: 2000);
    await pump(t, repo);
    expect(find.byKey(const ValueKey('calorie-chart')), findsOneWidget);
    expect(repo.calorieDayRanges, [30]);
    await t.tap(find.text('7 days'));
    await t.pumpAndSettle();
    expect(repo.calorieDayRanges, [30, 7]);
    await t.tap(find.text('30 days'));
    await t.pumpAndSettle();
    expect(repo.calorieDayRanges, [30, 7, 30]);
  });

  testWidgets("today's eaten lines are listed", (t) async {
    final repo = FakeReceipts()
      ..today = day(
        eaten: 1250,
        target: 2000,
        receipts: [
          (
            id: 'r-1',
            shop: 'Port Lepak',
            visitedAt: DateTime(2026, 11, 10, 20, 41),
            eatenKcal: 1250,
            items: [
              (name: 'Nasi Lemak', eaten: 2, kcal: 640, kcalSource: 'ai'),
              (name: 'Teh Ais', eaten: 0.5, kcal: null, kcalSource: null),
            ],
          ),
        ],
      );
    await pump(t, repo);
    expect(find.text('Port Lepak'), findsOneWidget);
    expect(find.text('2 × Nasi Lemak · 640 kcal'), findsOneWidget);
    expect(find.text('0.5 × Teh Ais'), findsOneWidget);
    expect(find.text('1250 kcal'), findsOneWidget);
  });

  testWidgets('no eaten lines today says so', (t) async {
    await pump(t, FakeReceipts()..today = day(target: 2000));
    expect(find.text('Nothing eaten today.'), findsOneWidget);
  });

  testWidgets(
    'meals sit among the receipts by time, with the day\'s macros; a tap offers to delete one',
    (t) async {
      final repo = FakeReceipts()
        ..today = day(
          eaten: 900,
          macros: (carbsG: 101.4, proteinG: 30, fatG: 22.6),
          receipts: [
            (
              id: 'r-1',
              shop: 'Port Lepak',
              visitedAt: DateTime(2026, 11, 10, 13),
              eatenKcal: 400,
              items: const [],
            ),
          ],
          meals: [
            (
              id: 'm-1',
              eatenAt: DateTime(2026, 11, 10, 20),
              eatenKcal: 500,
              macros: null,
              items: const [
                (
                  name: 'Nasi Lemak',
                  eaten: 1,
                  kcal: 500,
                  kcalSource: 'ai',
                  carbsG: null,
                  proteinG: null,
                  fatG: null,
                ),
              ],
            ),
          ],
        );
      await pump(t, repo);
      expect(
        find.text('Carbs 101 g · Protein 30 g · Fat 23 g'),
        findsOneWidget,
      );
      final meal = t.getTopLeft(
        find.byKey(const ValueKey('calories-meal-m-1')),
      );
      final receipt = t.getTopLeft(
        find.byKey(const ValueKey('calories-receipt-r-1')),
      );
      expect(meal.dy, lessThan(receipt.dy)); // newest first
      await t.scrollUntilVisible(find.text('1 × Nasi Lemak · 500 kcal'), 100);
      await t.tap(find.text('1 × Nasi Lemak · 500 kcal'));
      await t.pumpAndSettle();
      expect(find.text('Delete this meal?'), findsOneWidget);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(repo.removedMeals, ['m-1']);
    },
  );
}
