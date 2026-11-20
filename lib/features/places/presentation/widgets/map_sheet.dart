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

class _MapSheetState extends State<MapSheet> {
  static const _handle = 36.0;
  double _height = 1;

  double get _min => (widget.peek / _height).clamp(0.05, MapSheet.half - 0.05);
  double get _max =>
      (1 - widget.top / _height).clamp(MapSheet.half + 0.05, 1.0);

  void _to(double size) {
    if (!widget.controller.isAttached) return;
    widget.controller.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(MapSheet old) {
    super.didUpdateWidget(old);
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
                              child: widget.child,
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
