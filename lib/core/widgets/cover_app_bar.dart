import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A page's photo as its top bar: full width at the top, about 4:3, zooming on overscroll and drifting slower than
/// the page (parallax) as it scrolls away, then a plain paper bar with [title]. Pinned: the back button is always in
/// reach, on a paper chip so it reads over any photo. The photo is wrapped in a [Hero] ([heroTag]) so a card's photo
/// can fly into it; the flight shows the card's own picture (already decoded) both ways.
class CoverAppBar extends StatelessWidget {
  const CoverAppBar({
    super.key,
    required this.photo,
    required this.title,
    this.heroTag,
    this.actions = const [],
    this.height,
  });

  final Widget photo;
  final String title;
  final Object? heroTag;

  /// The bar's right side (e.g. a MoreMenu), each on the same paper chip as back.
  final List<Widget> actions;

  /// The open height; null = [heightFor] the screen (a photo). A placeholder with no photo is shorter.
  final double? height;

  /// The photo's height for a screen [width]: 4:3, at most 360 (a tablet keeps room for the recipe).
  static double heightFor(double width) => math.min(width * 3 / 4, 360);

  /// The flight between a card and this bar: always the card's picture, so it never shows a blank while the bar's
  /// own copy decodes.
  static Widget cardShuttle(
    BuildContext _,
    Animation<double> _,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final card = direction == HeroFlightDirection.push ? from : to;
    return (card.widget as Hero).child;
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: height ?? heightFor(width),
      backgroundColor: nb.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: nb.ink,
      automaticallyImplyLeading: false,
      leading: const _Chip(child: BackButton()),
      actions: [
        for (final a in actions) _Chip(child: a),
        const SizedBox(width: 8),
      ],
      title: _CollapsedTitle(title),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            heroTag == null
                ? photo
                : Hero(
                    tag: heroTag!,
                    flightShuttleBuilder: cardShuttle,
                    child: photo,
                  ),
            // A soft shade at the top: the status bar's icons stay readable over a bright photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, -0.4),
                  colors: [Color(0x55000000), Color(0x00000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar button on a round paper chip: readable over a photo and on the plain bar alike.
class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Center(
      child: Material(
        color: nb.paper.withValues(alpha: 0.88),
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: nb.ink.withValues(alpha: 0.3),
        child: SizedBox.square(dimension: 40, child: Center(child: child)),
      ),
    );
  }
}

/// The title appears only once the photo has scrolled away (it is already written under the photo).
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final s = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    // 1 = fully open, 0 = collapsed to the bar.
    final open = s == null || s.maxExtent == s.minExtent
        ? 0.0
        : ((s.currentExtent - s.minExtent) / (s.maxExtent - s.minExtent)).clamp(
            0.0,
            1.0,
          );
    return Opacity(
      opacity: (1 - open / 0.25).clamp(
        0.0,
        1.0,
      ), // fades in over the last quarter
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // The app's page title: handwritten, as on every other page.
        style: Notebook.of(context).hand.copyWith(fontSize: 30, height: 1),
      ),
    );
  }
}
