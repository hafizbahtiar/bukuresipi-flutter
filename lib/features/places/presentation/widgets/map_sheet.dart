import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';

/// Inside the map's sheet, a content's "done" (saved, edited, deleted) goes back to the sheet's list; in a modal
/// sheet (Home's nearby sheet) it pops as before.
class MapSheetScope extends InheritedWidget {
  const MapSheetScope({
    super.key,
    required this.close,
    required this.visible,
    required super.child,
  });

  /// [result] = what a modal sheet would have popped (a saved Place, for a search hit).
  final ValueChanged<Object?> close;

  /// How much of the content shows now (px): it is laid out at the sheet's full height and clipped.
  final double visible;

  @override
  bool updateShouldNotify(MapSheetScope oldWidget) =>
      visible != oldWidget.visible;
}

/// Inside the map's sheet, how tall its shown part is (a content keeps its buttons in it); null elsewhere.
double? sheetVisibleHeight(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<MapSheetScope>()?.visible;

/// "Done" for a sheet's content. Take it before an await, as Navigator.of(context).
ValueChanged<Object?> sheetCloser(BuildContext context) {
  final scope = context.getInheritedWidgetOfExactType<MapSheetScope>();
  if (scope != null) return scope.close;
  final navigator = Navigator.of(context);
  return navigator.pop;
}

/// The map's sheet, as Google Maps': always on screen, never closed, only lowered to its peek (the handle and the
/// first line of what it shows). Three heights: peek, half, full (the map's top stays in view); on a wide screen the
/// map page puts it in a left column ([sidePanelWidth]) and a pick opens it full. Its content's own
/// list scrolls it (the content's ListView takes the sheet's controller as its primary one); anywhere else drags it.
class MapSheet extends StatefulWidget {
  const MapSheet({
    super.key,
    required this.controller,
    required this.peek,
    required this.top,
    required this.shown,
    required this.child,
    required this.onClose,
    this.showClose = false,
  });

  final DraggableScrollableController controller;

  /// The peek's height in px (handle + one line).
  final double peek;

  /// Kept clear at the top when full (the search bar).
  final double top;

  /// Bumped on each new thing shown: the sheet rises to half for it.
  final int shown;

  final Widget child;

  /// A content's "done", or the X: back to the list.
  final ValueChanged<Object?> onClose;

  /// The X beside the handle (something picked; the list has none).
  final bool showClose;

  static const half = 0.5;

  @override
  State<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends State<MapSheet>
    with SingleTickerProviderStateMixin {
  static const _handle = 36.0;
  double _height = 1;

  /// A content change, as Wolt's modal sheet pages: 350 ms; the old content slides 30% of the sheet's width away and
  /// is gone by 150 ms, the new one slides in from the other side and fades in from 150 ms.
  static const _page = Duration(milliseconds: 350);
  static const _outFade = Interval(50 / 350, 150 / 350);
  static const _inFade = Interval(150 / 350, 1);
  static const _slide = Interval(50 / 350, 1, curve: Curves.fastOutSlowIn);

  /// Forward = something picked (comes in from the right); back = the list again (from the left).
  bool _forward = true;

  /// The content whose list scrolls the sheet. The sheet's scroll controller takes one list at a time, so while
  /// both contents show, the old one keeps it; the new one takes it once the old has faded out.
  Key? _attached;

  /// What the other content's list scrolls with meanwhile. Not PrimaryScrollController.none: a list under it never
  /// asks for the controller, so it would not notice being handed the sheet's.
  final _spare = ScrollController();

  /// The sheet's moves to a height, on this state's own clock: the sheet's animateTo runs on its list's and stops
  /// when that list detaches, which a content change does mid-move.
  late final _move = AnimationController(
    vsync: this,
    // The height as in Wolt's page change.
    duration: const Duration(milliseconds: 300),
  )..addListener(_moved);
  late final _moveCurve = CurvedAnimation(
    parent: _move,
    curve: Curves.fastOutSlowIn,
  );
  Tween<double> _moveSizes = Tween(begin: 0, end: 0);

  void _moved() {
    if (widget.controller.isAttached) {
      widget.controller.jumpTo(_moveSizes.evaluate(_moveCurve));
    }
  }

  @override
  void initState() {
    super.initState();
    _attached = widget.child.key;
  }

  @override
  void dispose() {
    _moveCurve.dispose();
    _move.dispose();
    _spare.dispose();
    super.dispose();
  }

  double get _min => (widget.peek / _height).clamp(0.05, MapSheet.half - 0.05);
  double get _max =>
      (1 - widget.top / _height).clamp(MapSheet.half + 0.05, 1.0);

  void _to(double size) {
    if (!widget.controller.isAttached) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.controller.jumpTo(size);
      return;
    }
    _moveSizes = Tween(begin: widget.controller.size, end: size);
    _move.forward(from: 0);
  }

  @override
  void didUpdateWidget(MapSheet old) {
    super.didUpdateWidget(old);
    final key = widget.child.key;
    if (old.child.key != key) {
      _forward = widget.showClose;
      if (MediaQuery.disableAnimationsOf(context)) {
        _attached = key;
      } else {
        // shortcut: changes faster than one every 150 ms for 350 ms can leave no list attached for a moment (a drag
        // then does nothing); a tap's pace never does.
        Future<void>.delayed(_page * (150 / 350), () {
          if (mounted && widget.child.key == key) {
            setState(() => _attached = key);
          }
        });
      }
    }
    if (old.shown != widget.shown) {
      WidgetsBinding.instance.addPostFrameCallback(
        // A wide screen's side panel rises all the way: half of a phone on its side is a few lines.
        (_) => _to(
          !widget.showClose
              ? _min
              : isWide(context)
              ? _max
              : MapSheet.half,
        ),
      );
    }
  }

  void _drag(DragUpdateDetails d) {
    if (!widget.controller.isAttached) return;
    _move.stop(); // the finger wins
    widget.controller.jumpTo(
      (widget.controller.size - d.primaryDelta! / _height).clamp(_min, _max),
    );
  }

  /// A fling goes one height up or down; a slow release settles on the nearest.
  void _settle(DragEndDetails d) {
    if (!widget.controller.isAttached) return;
    final sizes = [_min, MapSheet.half, _max];
    final now = widget.controller.size;
    final v = d.primaryVelocity ?? 0;
    final target = v < -600
        ? sizes.firstWhere((s) => s > now + 0.01, orElse: () => _max)
        : v > 600
        ? sizes.lastWhere((s) => s < now - 0.01, orElse: () => _min)
        : sizes.reduce((a, b) => (a - now).abs() < (b - now).abs() ? a : b);
    _to(target);
  }

  /// [animation] runs 0 -> 1 for the new content and 1 -> 0 for the old one.
  Widget _transition(Widget content, Animation<double> animation) {
    final incoming = content.key == widget.child.key;
    final side = (_forward ? 1 : -1) * (incoming ? 0.3 : -0.3);
    final attached = content.key == _attached;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = incoming ? animation.value : 1 - animation.value;
        final moved = incoming ? 1 - _slide.transform(t) : _slide.transform(t);
        // Always this widget, only its controller changes: the content's list keeps its state.
        final scroll = PrimaryScrollController.maybeOf(context);
        return FractionalTranslation(
          translation: Offset(side * moved, 0),
          child: Opacity(
            opacity: incoming
                ? _inFade.transform(t)
                : 1 - _outFade.transform(t),
            child: PrimaryScrollController(
              controller: attached && scroll != null ? scroll : _spare,
              child: child!,
            ),
          ),
        );
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        _height = box.maxHeight;
        return DraggableScrollableSheet(
          controller: widget.controller,
          initialChildSize: _min,
          minChildSize: _min,
          maxChildSize: _max,
          snap: true,
          snapSizes: const [MapSheet.half],
          builder: (context, scroll) => DecoratedBox(
            key: const ValueKey('map-sheet'),
            decoration: BoxDecoration(
              color: nb.paper,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              // A list that scrolls wins the drag (it moves the sheet first); the rest of the sheet drags it here.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _drag,
                onVerticalDragEnd: _settle,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: _handle,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: nb.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          if (widget.showClose)
                            Positioned(
                              right: 4,
                              top: 0,
                              child: IconButton(
                                key: const ValueKey('map-sheet-close'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 36,
                                ),
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonTooltip,
                                icon: Icon(Icons.close, color: nb.inkSoft),
                                onPressed: () => widget.onClose(null),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Laid out as tall as the sheet goes, clipped to its height: a lowered sheet cuts its content
                    // instead of squeezing it.
                    Expanded(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: _max * _height - _handle,
                          child: PrimaryScrollController(
                            controller: scroll,
                            // Rebuilt as the sheet moves; only the contents that ask for the height follow it.
                            child: ListenableBuilder(
                              listenable: widget.controller,
                              builder: (context, child) => MapSheetScope(
                                close: widget.onClose,
                                visible:
                                    (widget.controller.isAttached
                                            ? widget.controller.size
                                            : _min) *
                                        _height -
                                    _handle,
                                child: child!,
                              ),
                              child: AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : _page,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [...previous, ?current],
                                ),
                                // A new closure each build: the switcher re-runs the old content's transition too
                                // (direction, who holds the scroll).
                                transitionBuilder: (child, animation) =>
                                    _transition(child, animation),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
