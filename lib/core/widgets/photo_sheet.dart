import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _backdrop = 0.88;

/// A photo over a dark see-through backdrop, centred: pinch or double-tap to zoom, drag it away in any direction,
/// press back or ✕ to close. The same in light and dark mode on purpose: a photo reads best on black, and white on
/// black always contrasts.
///
/// [heroTag]: the tag of a [Hero] around the thumbnail that was tapped (see [PhotoHero]); the photo then grows out
/// of it and flies back into it on close, its corners morphing from [heroRadius] (the thumbnail's, e.g. half an
/// avatar's size = a circle) to square. [aspectRatio] (width / height, when known, e.g. 1 for an avatar) keeps the
/// corners on the photo itself during the flight.
Future<void> showPhotoDialog(
  BuildContext context,
  Uint8List bytes, {
  Object? heroTag,
  double heroRadius = 0,
  double? aspectRatio,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => _PhotoPage(
      bytes: bytes,
      heroTag: heroTag,
      heroRadius: heroRadius,
      aspectRatio: aspectRatio,
    ),
    // The backdrop and ✕ fade; the photo itself flies (Hero) when there is a thumbnail to fly from.
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  ),
);

/// The thumbnail side of [showPhotoDialog]'s flight: wrap the tapped picture and pass the same [tag]. Tags must be
/// unique on the page.
class PhotoHero extends StatelessWidget {
  const PhotoHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => Hero(tag: tag, child: child);
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    required this.bytes,
    required this.heroTag,
    required this.heroRadius,
    required this.aspectRatio,
  });

  final Uint8List bytes;
  final Object? heroTag;
  final double heroRadius;
  final double? aspectRatio;

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
    final t = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
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
