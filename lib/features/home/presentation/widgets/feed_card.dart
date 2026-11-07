import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A Home card in the book's style without its ruled lines: an index card (paper, thin border) with the photo on
/// top under a strip of washi tape, the title, and one line of detail. No photo = [icon] and the first letter of
/// [title], stamped on paper tinted [tint].
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.title,
    required this.meta,
    required this.icon,
    required this.tint,
    this.photo,
    this.badge,
    this.badgeIcon,
    required this.onTap,
  });

  final String title;
  final String meta;
  final IconData icon;
  final Color tint;

  /// Fills the photo box; receives the placeholder to show while it loads or when there is none.
  final Widget Function(Widget placeholder)? photo;

  /// A small label on the photo (e.g. "Says halal").
  final String? badge;
  final IconData? badgeIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final letter = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    final placeholder = ColoredBox(
      color: Color.alphaBlend(tint.withValues(alpha: 0.14), nb.paper),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nb.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tint.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Text(
                letter,
                style: nb.hand.copyWith(fontSize: 36, height: 1, color: tint),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -8,
              child: Icon(icon, size: 22, color: tint),
            ),
          ],
        ),
      ),
    );
    // The same slight tilt for a card every time (by its title), so the tape looks stuck on by hand.
    final tilt = ((title.hashCode % 5) - 2) * 0.04;
    return Material(
      color: nb.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: nb.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo?.call(placeholder) ?? placeholder,
                  Positioned(
                    top: -4,
                    left: 10,
                    child: Transform.rotate(
                      angle: -math.pi / 30 + tilt,
                      child: Container(
                        width: 44,
                        height: 14,
                        color: nb.kunyit.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (badge case final b?)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: nb.paper.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            if (badgeIcon case final i?)
                              Icon(i, size: 12, color: nb.pandanDeep),
                            Text(
                              b,
                              style: text.labelSmall?.copyWith(
                                color: nb.pandanDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
