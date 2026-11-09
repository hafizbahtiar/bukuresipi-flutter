import 'package:bukuresipi_flutter/features/achievements/data/achievements_api.dart';
import 'package:bukuresipi_flutter/features/achievements/domain/achievement.dart';
import 'package:bukuresipi_flutter/features/achievements/presentation/pages/badges_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> badge(
  String category, {
  int count = 0,
  int tier = 0,
  int? next = 5,
  bool fresh = false,
}) => {
  'category': category,
  'count': count,
  'tier': tier,
  'next': next,
  'steps': [5, 25, 75, 150, 300],
  'earnedAt': tier > 0 ? '2026-11-09T10:00:00.000Z' : null,
  'fresh': fresh,
};

class _FakeApi extends AchievementsApi {
  _FakeApi(this.rows) : super(Dio());
  List<Map<String, dynamic>> rows;
  int calls = 0;
  @override
  Future<List<Achievement>> list() async {
    calls++;
    return [for (final r in rows) ?Achievement.fromJson(r)];
  }
}

void main() {
  test('parse: progress between steps; an unknown category is skipped', () {
    final a = Achievement.fromJson(
      badge('explorer', count: 15, tier: 1, next: 25),
    )!;
    expect(a.shown, AchievementTier.bronze);
    expect(a.progress, closeTo(0.5, 0.001)); // 5 -> 25, at 15
    final none = Achievement.fromJson(badge('cook', count: 2))!;
    expect(none.earned, isFalse);
    expect(none.progress, closeTo(0.4, 0.001));
    final top = Achievement.fromJson(
      badge('critic', count: 400, tier: 5, next: null),
    )!;
    expect(top.shown, AchievementTier.diamond);
    expect(top.progress, 1);
    expect(Achievement.fromJson(badge('astronaut')), isNull);
  });

  Future<_FakeApi> pump(WidgetTester t, List<Map<String, dynamic>> rows) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final api = _FakeApi(rows);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BadgesPage(api: api),
      ),
    );
    await t.pumpAndSettle();
    return api;
  }

  testWidgets(
    'cards show the tier reached and the progress; a tap shows all five tiers',
    (t) async {
      await pump(t, [
        badge('explorer', count: 15, tier: 1, next: 25),
        badge('cook', count: 2),
      ]);
      expect(find.text('1 of 10 earned'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('15 / 25'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-badges')), findsNothing);
      await t.tap(find.byKey(const ValueKey('badge-explorer')));
      await t.pumpAndSettle();
      expect(find.text('Places saved in your book'), findsOneWidget);
      expect(find.text('You have 15'), findsOneWidget);
      for (final tier in AchievementTier.values) {
        expect(find.byKey(ValueKey('tier-${tier.name}')), findsOneWidget);
      }
      // Earned tiers in colour, the rest greyed.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tier-bronze')),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tier-silver')),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a tier reached on this read pops "New badge"; pulling down reads again',
    (t) async {
      final api = await pump(t, [
        badge('critic', count: 1, tier: 1, next: 5, fresh: true),
        badge('explorer'),
      ]);
      expect(find.byKey(const ValueKey('new-badges')), findsOneWidget);
      expect(find.text('Critic · Bronze'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('new-badges-ok')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-badges')), findsNothing);
      api.rows = [
        badge('critic', count: 1, tier: 1, next: 5),
        badge('explorer'),
      ];
      await t.fling(find.text('Critic'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(api.calls, 2);
      expect(find.byKey(const ValueKey('new-badges')), findsNothing);
    },
  );
}
