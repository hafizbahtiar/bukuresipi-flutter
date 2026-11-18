import 'package:flutter/widgets.dart';

/// How every photo [Hero] in the app flies, so they all move alike.
///
/// Flutter's own flight keeps the page's pace as it is (linear), and MaterialApp bends its path into an arc. Here
/// the photo goes straight, easing out of where it was and into where it lands, over the page's whole transition.
/// Give both ends of a flight the same [heroFlight] (push uses the new page's, pop the old one's).
CreateRectTween heroFlight() =>
    (begin, end) => _EasedRectTween(begin, end, _pace);

/// [animation] at the same pace as [heroFlight], for what a shuttle morphs on the way (its corners), so the morph
/// and the flight stay in step.
Animation<double> heroPace(Animation<double> animation) =>
    CurvedAnimation(parent: animation, curve: _pace);

const _pace = Curves.easeInOutCubic;

class _EasedRectTween extends RectTween {
  _EasedRectTween(Rect? begin, Rect? end, this.curve)
    : super(begin: begin, end: end);

  final Curve curve;

  @override
  Rect? lerp(double t) => super.lerp(curve.transform(t));
}
