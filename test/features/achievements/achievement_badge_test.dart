import 'dart:io';

import 'package:bukuresipi_flutter/features/achievements/domain/achievement.dart';
import 'package:bukuresipi_flutter/features/achievements/presentation/widgets/achievement_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every category x tier has its art', () {
    for (final c in AchievementCategory.values) {
      for (final t in AchievementTier.values) {
        expect(
          File(AchievementBadge.asset(c, t)).existsSync(),
          isTrue,
          reason: AchievementBadge.asset(c, t),
        );
      }
    }
  });

  testWidgets('a locked badge is the same art, greyed', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            AchievementBadge(
              category: AchievementCategory.cook,
              tier: AchievementTier.gold,
              label: 'Cook, gold',
            ),
            AchievementBadge(
              category: AchievementCategory.cook,
              tier: AchievementTier.diamond,
              locked: true,
            ),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Cook, gold'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
