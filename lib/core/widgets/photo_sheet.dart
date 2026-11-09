import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// A photo in a dark bottom sheet: pinch or double-tap to zoom, swipe it down (or tap outside) to close.
Future<void> showPhotoSheet(BuildContext context, Uint8List bytes) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        // The photo takes the drags (zoom, pan), so a swipe down is its slide-out: it pops the sheet.
        child: ExtendedImageSlidePage(
          slideAxis: SlideAxis.vertical,
          slideType: SlideType.onlyImage,
          slidePageBackgroundHandler: (_, _) => Colors.transparent,
          child: ExtendedImage.memory(
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
      ),
    );
