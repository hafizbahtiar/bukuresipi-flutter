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

/// A floating sheet whose content changes height (the next step, a list arriving): its top edge moves there.
/// Timings as wolt_modal_sheet's pagination: the height over 300 of a step's 350 ms.
const _resizeMotion = Duration(milliseconds: 300);
const _stepMotion = Duration(milliseconds: 350);

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
                  // A new height (the next step: [SheetSwitcher]) moves the top edge, as when it opens;
                  // the bottom stays on its line.
                  Flexible(
                    child: AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : _resizeMotion,
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.bottomCenter,
                      child: widget.child,
                    ),
                  ),
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

/// Steps inside one floating sheet (a menu, then what the picked row needs): give each step its own key. Never
/// close a sheet to open the next one. Choreography from wolt_modal_sheet (350 ms): the top edge moves to the new
/// height from the start (the sheet's AnimatedSize); the old step fades out fast (50-150 ms) and the new one fades in
/// only after it (150-350 ms), so their text never overlaps; both slide left by 30% of the width (50-350 ms), the
/// new one arriving from the right: forward. A step has its [SheetStepTitle] with Back.
class SheetSwitcher extends StatelessWidget {
  const SheetSwitcher({super.key, required this.child, this.forward = true});

  final Widget child;

  /// false = back to the step before: the new step comes from the left, the old one leaves to the right.
  final bool forward;

  static const _slide = Interval(50 / 350, 1, curve: Curves.fastOutSlowIn);
  static const _fadeOut = Interval(50 / 350, 150 / 350);
  static const _fadeIn = Interval(150 / 350, 1);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _stepMotion,
    transitionBuilder: (step, animation) {
      final incoming = step.key == child.key;
      return AnimatedBuilder(
        animation: animation,
        child: step,
        builder: (_, step) {
          // Time since the switch, 0..1 (the outgoing step's animation runs backwards).
          final t = incoming ? animation.value : 1 - animation.value;
          final moved = _slide.transform(t);
          return Opacity(
            opacity: incoming
                ? _fadeIn.transform(t)
                : 1 - _fadeOut.transform(t),
            child: FractionalTranslation(
              translation: Offset(
                (forward ? 0.3 : -0.3) * (incoming ? 1 - moved : -moved),
                0,
              ),
              child: step,
            ),
          );
        },
      );
    },
    // Only the new step sizes the sheet (the old one is laid over it, on the bottom line), so the edge moves at once.
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.bottomCenter,
      children: [
        for (final p in previous)
          Positioned(left: 0, right: 0, bottom: 0, child: p),
        ?current,
      ],
    ),
    child: child,
  );
}

/// A sheet step's title row ([SheetSwitcher]), with Back to the step before; the arrow lines up with the rows' icons.
class SheetStepTitle extends StatelessWidget {
  const SheetStepTitle({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: spaceXs, right: spaceM),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('sheet-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: spaceXs),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );
}

/// Camera or photos: [camera] names what the camera is for ("Snap a receipt"). A step of a sheet
/// ([SheetSwitcher]), or a sheet of its own ([showPhotoSourceSheet]).
class PhotoSourceTiles extends StatelessWidget {
  const PhotoSourceTiles({
    super.key,
    required this.camera,
    required this.onPick,
  });

  final String camera;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        key: const ValueKey('photo-camera'),
        leading: const Icon(Icons.photo_camera_outlined),
        title: Text(camera),
        onTap: () => onPick(ImageSource.camera),
      ),
      ListTile(
        key: const ValueKey('photo-gallery'),
        leading: const Icon(Icons.photo_library_outlined),
        title: Text(AppLocalizations.of(context).receiptFromGallery),
        onTap: () => onPick(ImageSource.gallery),
      ),
    ],
  );
}

/// Camera or photos, as a floating sheet of its own. null = closed.
Future<ImageSource?> showPhotoSourceSheet(
  BuildContext context, {
  required String camera,
}) => showBaseSheet<ImageSource>(
  context,
  builder: (sheet) => PhotoSourceTiles(
    camera: camera,
    onPick: (source) => Navigator.pop(sheet, source),
  ),
);
