import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_constant.dart';

/// On a tablet, a desktop window or a phone on its side, a page of lists and forms stays a readable column (a
/// notebook page on the desk) instead of stretching edge to edge. Under [maxWidth] it is the page as is. Inside, the
/// page sees a [maxWidth]-wide screen (MediaQuery), so its own layout stays the phone's. Not for the map, the feed's
/// grid or photos: they use the whole screen.
class WidePage extends StatelessWidget {
  const WidePage({super.key, required this.child});

  static const maxWidth = readableWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;
    final nb = Notebook.of(context);
    return ColoredBox(
      color: nb.mist,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nb.paper,
            boxShadow: [
              BoxShadow(color: nb.ink.withValues(alpha: 0.12), blurRadius: 16),
            ],
          ),
          child: SizedBox(
            width: maxWidth,
            child: MediaQuery(
              // The side insets (a notch on its side) are outside the column now.
              data: media
                  .removePadding(removeLeft: true, removeRight: true)
                  .copyWith(
                    size: Size(
                      math.min(maxWidth, media.size.width),
                      media.size.height,
                    ),
                  ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
