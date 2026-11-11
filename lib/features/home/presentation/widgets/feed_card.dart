import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton.dart';

/// One fact on a card's bottom row: an icon and a short text ("4.6 (12)", "Says halal", "8 ingredients").
class FeedFact {
  const FeedFact(this.icon, this.text, {this.strong = false});

  final IconData icon;
  final String text;

  /// Drawn in the brand colour (a rating, a halal claim); plain facts stay grey.
  final bool strong;
}

/// A Home card. Every kind has the same structure, so the grid reads as one list: the photo (or a plain panel with
/// [icon]), the [kind] label, a two-line [title], one [subtitle] line, and the [facts] row at the bottom. [tag] is
/// the one thing pinned on the photo (e.g. "Near me · 300 m").
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.kind,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.facts = const [],
    this.photo,
    this.tag,
    this.tagIcon,
    this.drawing,
  });

  final String kind;
  final String title;
  final String? subtitle;
  final List<FeedFact> facts;
  final IconData icon;

  /// An asset drawn in the photo box when there is no photo (a recipe's cooking drawing), in place of [icon].
  final String? drawing;

  /// Fills the photo box; receives the placeholder to show while it loads or when there is none.
  final Widget Function(Widget placeholder)? photo;

  final String? tag;
  final IconData? tagIcon;
  final VoidCallback onTap;

  /// The card's height for its width: the 4:3 photo plus the text block (scaled with the user's text size).
  static double heightFor(double width, TextScaler scaler) =>
      width * 3 / 4 + scaler.scale(96) + 20;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    // The home page is mist too: the photo box takes the container surface so an empty one still reads as a box.
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: drawing == null
            ? Icon(icon, size: 36, color: nb.inkSoft.withValues(alpha: 0.5))
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  drawing!,
                  key: const ValueKey('feed-card-drawing'),
                  fit: BoxFit.contain,
                  cacheWidth: 400,
                  excludeFromSemantics: true,
                ),
              ),
      ),
    );
    return Material(
      color: nb.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: nb.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo?.call(placeholder) ?? placeholder,
                  if (tag case final t?)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _Pill(icon: tagIcon, text: t),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.toUpperCase(),
                      maxLines: 1,
                      style: text.labelSmall?.copyWith(
                        color: nb.pandan,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle case final s? when s.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          s,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
                        ),
                      ),
                    const Spacer(),
                    if (facts.isNotEmpty)
                      Row(
                        children: [
                          for (final (i, f) in facts.indexed) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Flexible(child: _Fact(f)),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [FeedCard] still loading: the same paper, photo box and text block, as shimmering shapes. Same height for the
/// same width ([FeedCard.heightFor]), so nothing moves when the real cards arrive.
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key, this.wide = true});

  /// Varies the line lengths, so a grid of them does not look stamped.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: nb.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AspectRatio(
                aspectRatio: 4 / 3,
                child: SkeletonBox(height: double.infinity, radius: 0),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final w = box.maxWidth;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: w * 0.32, height: 8), // kind
                          const SizedBox(height: 8),
                          SkeletonBox(width: w * (wide ? 0.92 : 0.8)), // title
                          const SizedBox(height: 6),
                          SkeletonBox(width: w * (wide ? 0.6 : 0.7)),
                          const SizedBox(height: 8),
                          SkeletonBox(width: w * (wide ? 0.5 : 0.4), height: 9),
                          const Spacer(),
                          SkeletonBox(width: w * 0.38, height: 10), // facts
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.fact);

  final FeedFact fact;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(fact.icon, size: 14, color: fact.strong ? nb.pandan : nb.inkSoft),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            fact.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fact.strong ? nb.pandanDeep : nb.inkSoft,
              fontWeight: fact.strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: nb.paper.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          if (icon case final i?) Icon(i, size: 12, color: nb.pandanDeep),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: nb.pandanDeep, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
