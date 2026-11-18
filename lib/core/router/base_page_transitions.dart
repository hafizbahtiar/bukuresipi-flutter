import 'package:flutter/material.dart';

/// A page that opens with the standard Material transition, not the book flip: a place's branch and its edit pages.
/// Not a MaterialPageRoute (the theme would flip it), so the page under it does not curl either.
Route<T> standardRoute<T>(WidgetBuilder builder) {
  const motion = FadeForwardsPageTransitionsBuilder();
  return PageRouteBuilder<T>(
    transitionDuration: motion.transitionDuration,
    reverseTransitionDuration: motion.reverseTransitionDuration,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) =>
        motion.buildTransitions(
          ModalRoute.of(context)! as PageRoute<T>,
          context,
          animation,
          secondary,
          child,
        ),
  );
}
