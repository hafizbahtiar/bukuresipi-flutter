import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// A photo full screen on black: pinch or double-tap to zoom, drag to pan.
class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({super.key, required this.bytes, this.title});

  final Uint8List bytes;
  final String? title;

  static Future<void> open(
    BuildContext context,
    Uint8List bytes, {
    String? title,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerPage(bytes: bytes, title: title),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!),
      ),
      body: ExtendedImage.memory(
        bytes,
        key: const ValueKey('photo-viewer'),
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
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
    );
  }
}
