import 'package:flutter/material.dart';

import '../../domain/achievement.dart';

/// A badge from `assets/badges/<category>_<tier>.png` (512 px, built by design/badges/build.py). [locked] = not
/// earned yet: the same medal in faded grey.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.category,
    required this.tier,
    this.locked = false,
    this.size = 72,
    this.label,
  });

  final AchievementCategory category;
  final AchievementTier tier;
  final bool locked;
  final double size;

  /// For screen readers, e.g. "Explorer, gold".
  final String? label;

  static String asset(AchievementCategory c, AchievementTier t) =>
      'assets/badges/${c.name}_${t.name}.png';

  static const _grey = ColorFilter.matrix([
    0.30, 0.45, 0.10, 0, 20, //
    0.30, 0.45, 0.10, 0, 20,
    0.30, 0.45, 0.10, 0, 20,
    0, 0, 0, 0.5, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset(category, tier),
      width: size,
      height: size,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      semanticLabel: label,
      excludeFromSemantics: label == null,
    );
    return locked ? ColorFiltered(colorFilter: _grey, child: image) : image;
  }
}
