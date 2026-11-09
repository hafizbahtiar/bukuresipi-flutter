import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// A photo full screen on black: pinch or double-tap to zoom, drag to pan, swipe up or down to close (the
/// background fades as it goes).
class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({super.key, required this.bytes, this.title});

  final Uint8List bytes;
  final String? title;

  /// A see-through route: while the photo is swiped away, the page under it shows through.
  static Future<void> open(
    BuildContext context,
    Uint8List bytes, {
    String? title,
  }) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) => PhotoViewerPage(bytes: bytes, title: title),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      slideType: SlideType.onlyImage,
      // Black fading out over half the screen's height.
      slidePageBackgroundHandler: (offset, size) => Colors.black.withValues(
        alpha: (1 - offset.dy.abs() / (size.height / 2)).clamp(0.0, 1.0),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          leading: const CloseButton(),
          title: title == null ? null : Text(title!),
        ),
        body: ExtendedImage.memory(
          bytes,
          key: const ValueKey('photo-viewer'),
          fit: BoxFit.contain,
          mode: ExtendedImageMode.gesture,
          enableSlideOutPage: true,
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
    );
  }
}
