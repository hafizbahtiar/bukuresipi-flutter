import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';

/// A full-width sheet's motion: a calm slide in, a quicker one out (the sheet's own decelerating curve).
const sheetMotion = AnimationStyle(
  duration: Duration(milliseconds: 380),
  reverseDuration: Duration(milliseconds: 260),
);

/// How long a floating sheet takes to grow out of its line, or fold back into it.
const _floatMotion = Duration(milliseconds: 340);

/// The gap a floating sheet keeps from the screen's sides and bottom.
const _floatGap = 12.0;

/// A modal bottom sheet. [floating] (default): a card held off the screen's sides and bottom, rounded all round;
/// best for short menus. Its bottom edge stays put on an unseen line: it grows up out of it and folds back down
/// into it (drag the handle down to close). false: the full-width sheet sliding from the screen's edge, for long
/// pickers and forms. [builder] gives the content only (no SafeArea).
Future<T?> showBaseSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool floating = true,
}) {
  if (!floating) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true, // as tall as its content, up to the screen
      useSafeArea: true,
      sheetAnimationStyle: sheetMotion,
      builder: (sheet) => SafeArea(child: builder(sheet)),
    );
  }
  // Not showModalBottomSheet: its sheet can only slide in from the screen's edge.
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _floatMotion,
    // The card animates itself (it grows); no fade or slide of the whole page.
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (_, animation, _) => _FloatingSheet(
      animation: animation,
      child: Builder(builder: builder),
    ),
  );
}

class _FloatingSheet extends StatefulWidget {
  const _FloatingSheet({required this.animation, required this.child});

  /// The route's: 0 = folded into the line, 1 = open.
  final Animation<double> animation;
  final Widget child;

  @override
  State<_FloatingSheet> createState() => _FloatingSheetState();
}

class _FloatingSheetState extends State<_FloatingSheet>
    with SingleTickerProviderStateMixin {
  /// How much of the card the finger leaves open while dragging the handle down (1 = all).
  late final _drag = AnimationController(vsync: this, value: 1);

  late final _open = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The whole card's content, measured unfolded: a drag of its height = fully closed.
  final _content = GlobalKey();

  @override
  void dispose() {
    _open.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails d) {
    final height = _content.currentContext?.size?.height ?? 1;
    _drag.value -= (d.primaryDelta ?? 0) / height;
  }

  void _dragEnd(DragEndDetails d) {
    // Far enough or flicked: close from where it is (the route folds on from the finger's point).
    if ((d.primaryVelocity ?? 0) > 700 || _drag.value < 0.7) {
      Navigator.maybePop(context);
    } else {
      _drag.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final media = MediaQuery.of(context);
    // Above the gesture bar, or the keyboard while it is open.
    final bottom =
        _floatGap + math.max(media.padding.bottom, media.viewInsets.bottom);
    return Padding(
      padding: EdgeInsets.fromLTRB(_floatGap, 0, _floatGap, bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640, // as Material's sheets on a tablet
            maxHeight: media.size.height - media.padding.top - bottom - spaceL,
          ),
          child: GestureDetector(
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: _dragEnd,
            child: AnimatedBuilder(
              animation: Listenable.merge([_open, _drag]),
              // The card is as tall as the part let out of the line; the content stays put, aligned to the
              // bottom, so the top edge (with the handle) is what moves.
              builder: (context, content) => Material(
                color: nb.paper,
                elevation: 8,
                shadowColor: nb.ink.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: (_open.value * _drag.value).clamp(0.0, 1.0),
                  child: content,
                ),
              ),
              child: Column(
                key: _content,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The drag handle, as the theme's (which only shows on a full-width sheet).
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: spaceS + 2,
                        bottom: spaceS,
                      ),
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: nb.inkSoft.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(child: widget.child),
                  const SizedBox(height: spaceS),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Camera or photos, as a floating sheet: [camera] names what the camera is for ("Snap a receipt"). null = closed.
Future<ImageSource?> showPhotoSourceSheet(
  BuildContext context, {
  required String camera,
}) {
  final l = AppLocalizations.of(context);
  return showBaseSheet<ImageSource>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(camera),
          onTap: () => Navigator.pop(sheet, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l.receiptFromGallery),
          onTap: () => Navigator.pop(sheet, ImageSource.gallery),
        ),
      ],
    ),
  );
}
