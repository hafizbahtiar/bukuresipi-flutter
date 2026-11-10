import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A photo over a dark see-through backdrop: pinch or double-tap to zoom, swipe it down, press back or ✕ to close.
/// The same in light and dark mode on purpose: a photo reads best on black, and white on black always contrasts.
Future<void> showPhotoDialog(BuildContext context, Uint8List bytes) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle
            .light, // light status-bar icons on the dark backdrop
        child: Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // The photo takes the drags (zoom, pan), so a swipe down is its slide-out: it closes the dialog.
              ExtendedImageSlidePage(
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
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton.filled(
                      key: const ValueKey('photo-close'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
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
        ),
      ),
    );
