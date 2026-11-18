import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base.dart' show MenuAction;
import 'hero_motion.dart';

const _backdrop = 0.88;

/// A photo over a dark see-through backdrop, centred: pinch or double-tap to zoom, drag it away in any direction,
/// press back or ✕ to close. The same in light and dark mode on purpose: a photo reads best on black, and white on
/// black always contrasts.
///
/// [heroTag]: the tag of a [Hero] around the thumbnail that was tapped (see [PhotoHero]); the photo then grows out
/// of it and flies back into it on close, its corners morphing from [heroRadius] (the thumbnail's, e.g. half an
/// avatar's size = a circle) to square. [aspectRatio] (width / height, when known, e.g. 1 for an avatar) keeps the
/// corners on the photo itself during the flight.
///
/// [actions]: buttons along the bottom (e.g. Change, Remove on one's own picture). A tap closes the photo first,
/// then runs the action.
Future<void> showPhotoDialog(
  BuildContext context,
  Uint8List bytes, {
  Object? heroTag,
  double heroRadius = 0,
  double? aspectRatio,
  List<MenuAction> actions = const [],
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final label = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  // Decoded before the flight: the flying copy (Image.memory) and the landed one (ExtendedImage) are different
  // cache keys, and a full photo decoded mid-flight showed as a blank, jerky first open.
  await Future.wait([
    precacheImage(MemoryImage(bytes), context),
    precacheImage(ExtendedMemoryImageProvider(bytes), context),
  ]);
  await navigator.push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierLabel: label,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, _, _) => _PhotoPage(
        bytes: bytes,
        heroTag: heroTag,
        heroRadius: heroRadius,
        aspectRatio: aspectRatio,
        actions: actions,
      ),
      // The backdrop and ✕ fade; the photo itself flies (Hero) when there is a thumbnail to fly from.
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// The thumbnail side of [showPhotoDialog]'s flight: wrap the tapped picture and pass the same [tag]. Tags must be
/// unique on the page.
class PhotoHero extends StatelessWidget {
  const PhotoHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Hero(tag: tag, createRectTween: _flight, child: child);
}

/// The path between a thumbnail and the open photo: both Heroes share it.
final _flight = heroFlight();

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    required this.bytes,
    required this.heroTag,
    required this.heroRadius,
    required this.aspectRatio,
    required this.actions,
  });

  final Uint8List bytes;
  final Object? heroTag;
  final double heroRadius;
  final double? aspectRatio;
  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle
          .light, // light status-bar icons on the dark backdrop
      child: Stack(
        children: [
          // Fills the screen, so the photo (fit: contain) sits in the middle. The photo takes the drags (zoom, pan);
          // dragged far enough in any direction it slides out and closes the page, the backdrop fading as it goes.
          Positioned.fill(
            child: ExtendedImageSlidePage(
              slideAxis: SlideAxis.both,
              slideType: SlideType.onlyImage,
              slidePageBackgroundHandler: (offset, size) {
                final gone = math.min(
                  1.0,
                  offset.distance / (size.shortestSide * 0.6),
                );
                return Colors.black.withValues(alpha: _backdrop * (1 - gone));
              },
              child: ExtendedImage.memory(
                bytes,
                key: const ValueKey('photo-viewer'),
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                enableSlideOutPage: true,
                heroBuilderForSlidingPage: heroTag == null
                    ? null
                    : (image) => Hero(
                        tag: heroTag!,
                        createRectTween: _flight,
                        flightShuttleBuilder: _shuttle,
                        child: image,
                      ),
                initGestureConfigHandler: (_) => GestureConfig(
                  minScale: 1,
                  maxScale: 4,
                  animationMaxScale: 4.5,
                  inPageView: false,
                ),
                onDoubleTap: (state) {
                  final scale = state.gestureDetails?.totalScale ?? 1;
                  state.handleDoubleTap(
                    scale: scale > 1 ? 1 : 2.5,
                    doubleTapPosition: state.pointerDownPosition,
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  key: const ValueKey('photo-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final a in actions)
                        FilledButton.tonalIcon(
                          key: ValueKey('photo-action-${a.label}'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            // White on the black backdrop; a danger action in a red that reads on black.
                            foregroundColor: a.danger
                                ? const Color(0xFFFF8A80)
                                : Colors.white,
                          ),
                          onPressed: a.onTap == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  a.onTap!();
                                },
                          icon: Icon(a.icon, size: 20),
                          label: Text(a.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // What flies between the thumbnail and the open photo (both ways; on close the animation runs back to 0):
  // the photo itself, its corners going from the thumbnail's rounding to square.
  Widget _shuttle(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final t = heroPace(animation); // corners morph in step with the flight
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final radius = BorderRadius.circular(
          lerpDouble(heroRadius, 0, t.value)!,
        );
        final photo = aspectRatio;
        return photo == null
            ? ClipRRect(
                borderRadius: radius,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              )
            : Center(
                child: AspectRatio(
                  aspectRatio: photo,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              );
      },
    );
  }
}
