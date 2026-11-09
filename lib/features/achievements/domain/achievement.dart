/// What a badge counts. The counts and their tier steps live on the server (bukuresipi-hono
/// `src/features/achievements/service.ts`); the app draws them. Art: `design/badges/build.py`.
enum AchievementCategory { explorer, traveller, regular, cook, critic, helper }

/// Lowest first; the badge shows index + 1 stars.
enum AchievementTier { bronze, silver, gold, platinum, diamond }

/// One category's badge for the caller (GET /achievements).
class Achievement {
  const Achievement({
    required this.category,
    required this.count,
    required this.tier,
    required this.steps,
    this.next,
    this.earnedAt,
    this.fresh = false,
  });

  final AchievementCategory category;
  final int count;

  /// 0 = none yet, 1 bronze .. 5 diamond: the highest ever reached (kept when the count drops).
  final int tier;

  /// The count the next tier needs; null at diamond.
  final int? next;

  /// The count each tier needs, bronze first.
  final List<int> steps;
  final DateTime? earnedAt;

  /// Reached on this read: show "New badge".
  final bool fresh;

  /// The tier to draw: the one earned, else bronze (greyed by the caller).
  AchievementTier get shown => AchievementTier.values[tier == 0 ? 0 : tier - 1];
  bool get earned => tier > 0;

  /// Progress from the current tier's step to the next (1 at diamond).
  double get progress {
    final n = next;
    if (n == null) return 1;
    final from = tier == 0 ? 0 : steps[tier - 1];
    return ((count - from) / (n - from)).clamp(0.0, 1.0);
  }

  /// null = a category this app version does not know (a newer server): skipped.
  static Achievement? fromJson(Map<String, dynamic> j) {
    final category = AchievementCategory.values
        .where((c) => c.name == j['category'])
        .firstOrNull;
    if (category == null) return null;
    return Achievement(
      category: category,
      count: j['count'] as int,
      tier: (j['tier'] as int).clamp(0, AchievementTier.values.length),
      next: j['next'] as int?,
      steps: (j['steps'] as List).cast<int>(),
      earnedAt: switch (j['earnedAt']) {
        final String s => DateTime.tryParse(s)?.toLocal(),
        _ => null,
      },
      fresh: j['fresh'] as bool? ?? false,
    );
  }
}
