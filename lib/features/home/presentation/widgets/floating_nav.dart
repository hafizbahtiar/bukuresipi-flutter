import 'dart:math' show sqrt;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_bar.dart';

/// One tab of [FloatingNav]: its icons and name (the tooltip and screen-reader label; no text shows on the bar).
class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label, {this.picture});

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Shown instead of the icons (the user's avatar on Account), ringed in the active colour when active.
  final Widget? picture;
}

const _motion = Duration(milliseconds: 260);
const _curve = Curves.easeOutCubic;

/// Home's tab bar: a frosted pill floating over the page, icons only (long-press = the name). The active tab sits
/// on a chip that flows to a tapped tab like a drop of water, and can be dragged along the bar like a [PillSwitch]'s: let go and it
/// settles on the nearest tab (a flick goes on in its direction). "+" is a round button in the middle, not a tab:
/// the chip passes it by. [vertical]: the same pill standing on the left edge (a navigation rail, as Material's
/// tablet layout has it), top to bottom in the same order.
class FloatingNav extends StatefulWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.addLabel,
    required this.onAdd,
    this.compact = false,
    this.vertical = false,
  });

  final bool vertical;

  /// The page is scrolling: the whole bar shrinks a little (towards the bottom edge), back to full size after.
  final bool compact;

  final List<NavItem> items;
  final int selected;

  /// A tab tapped (the open one too: the page may go back to its top) or dragged to.
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;

  static const height = GlassBar.height;

  @override
  State<FloatingNav> createState() => _FloatingNavState();
}

class _FloatingNavState extends State<FloatingNav>
    with TickerProviderStateMixin {
  /// The chip's place in slots while a finger drags it; null = resting on the selected tab.
  double? _drag;

  static const _compactScale = 0.88;

  /// Slightly under-damped, as iOS's: soft, with a barely-there settle at the end.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 220,
    ratio: 0.82,
  );

  /// The bar's scale, moved by a spring: a change mid-way carries on from the current speed instead of restarting.
  late final _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.compact ? _compactScale : 1,
  );

  /// The chip's two ends on their springs (see [_Flow]).
  late final _flow = _Flow(this, _slotOf(widget.selected).toDouble());

  void _chipTo(double slot, {bool held = false}) => _flow.moveTo(
    slot,
    still: MediaQuery.disableAnimationsOf(context),
    held: held,
  );

  @override
  void didUpdateWidget(covariant FloatingNav old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && _drag == null) {
      _chipTo(_slotOf(widget.selected).toDouble());
    }
    if (old.compact == widget.compact) return;
    final target = widget.compact ? _compactScale : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
    } else {
      _scale.animateWith(
        SpringSimulation(_spring, _scale.value, target, _scale.velocity),
      );
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _scale.dispose();
    super.dispose();
  }

  int get _slots => widget.items.length + 1;
  int get _mid => widget.items.length ~/ 2; // the "+" slot
  int _slotOf(int tab) => tab < _mid ? tab : tab + 1;
  int _tabOf(int slot) => slot < _mid ? slot : slot - 1;

  /// The tab slot to settle on from [at]: the nearest, or the next one in a flick's direction.
  int _settle(double at, double velocity) {
    final tabs = [
      for (var s = 0; s < _slots; s++)
        if (s != _mid) s,
    ];
    if (velocity > 300) {
      return tabs.firstWhere((s) => s > at, orElse: () => tabs.last);
    }
    if (velocity < -300) {
      return tabs.lastWhere((s) => s < at, orElse: () => tabs.first);
    }
    tabs.sort((a, b) => (a - at).abs().compareTo((b - at).abs()));
    return tabs.first;
  }

  void _dragEnd(DragEndDetails d) {
    final at = _drag;
    if (at == null) return;
    final slot = _settle(at, d.primaryVelocity ?? 0);
    final tab = _tabOf(slot);
    setState(() => _drag = null);
    _chipTo(slot.toDouble());
    if (tab != widget.selected) {
      HapticFeedback.selectionClick();
      widget.onSelected(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Under the finger the nearest tab lights up; at rest, the selected one.
    final lit = switch (_drag) {
      final at? => _settle(at, 0),
      null => _slotOf(widget.selected),
    };
    final vertical = widget.vertical;
    // Along the bar: x on the phone's bar, y on the rail.
    double along(Offset o) => vertical ? o.dy : o.dx;
    void dragStart(DragStartDetails d, double w) {
      final at = _slotOf(widget.selected);
      if (along(d.localPosition) ~/ w != at) return;
      setState(() => _drag = at.toDouble());
    }

    void dragUpdate(DragUpdateDetails d, double w) {
      final at = _drag;
      if (at == null) return;
      final to = (at + along(d.delta) / w).clamp(0, _slots - 1).toDouble();
      // The chip moves on its own layer: the tabs are rebuilt only when another one lights up.
      final relit = _settle(to, 0) != _settle(at, 0);
      _drag = to;
      _chipTo(to, held: true);
      if (relit) setState(() {});
    }

    void dragCancel() {
      setState(() => _drag = null);
      _chipTo(_slotOf(widget.selected).toDouble());
    }

    return SafeArea(
      top: vertical,
      right: !vertical,
      minimum: vertical
          ? const EdgeInsets.all(12)
          : const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: ScaleTransition(
        key: const ValueKey('nav-bar-scale'),
        scale: _scale,
        alignment: vertical ? Alignment.centerLeft : Alignment.bottomCenter,
        // The spring only changes the transform: the bar (icons, shadow) is not repainted each frame of it.
        child: RepaintBoundary(
          // Standing, a slot is as tall as the phone bar is (shorter on a phone on its side, which has less height).
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: vertical
                  ? _slots * GlassBar.height + 4
                  : double.infinity,
            ),
            child: GlassBar(
              vertical: vertical,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = (vertical ? box.maxHeight : box.maxWidth) / _slots;
                  final slots = [
                    for (var s = 0; s < _slots; s++)
                      SizedBox(
                        width: vertical ? null : w,
                        height: vertical ? w : null,
                        child: s == _mid
                            ? _AddButton(
                                label: widget.addLabel,
                                onTap: widget.onAdd,
                              )
                            : _Tab(
                                key: ValueKey('nav-tab-${_tabOf(s)}'),
                                item: widget.items[_tabOf(s)],
                                selected: _tabOf(s) == widget.selected,
                                lit: s == lit,
                                still: still,
                                // Also the tab already open: its page goes back to the top.
                                onTap: () => widget.onSelected(_tabOf(s)),
                              ),
                      ),
                  ];
                  return GestureDetector(
                    // From the touch, not from where the drag was recognised: the chip stays under the finger.
                    dragStartBehavior: DragStartBehavior.down,
                    // Only the chip is dragged: a drag that starts on another tab, or on "+", moves nothing.
                    onHorizontalDragStart: vertical
                        ? null
                        : (d) => dragStart(d, w),
                    onHorizontalDragUpdate: vertical
                        ? null
                        : (d) => dragUpdate(d, w),
                    onHorizontalDragEnd: vertical ? null : _dragEnd,
                    onHorizontalDragCancel: vertical ? null : dragCancel,
                    onVerticalDragStart: vertical
                        ? (d) => dragStart(d, w)
                        : null,
                    onVerticalDragUpdate: vertical
                        ? (d) => dragUpdate(d, w)
                        : null,
                    onVerticalDragEnd: vertical ? _dragEnd : null,
                    onVerticalDragCancel: vertical ? dragCancel : null,
                    child: Stack(
                      children: [
                        // The chip, painted on its own layer from [_flow]: no rebuild, layout or repaint of the
                        // bar and its icons while it moves.
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey('nav-chip'),
                              painter: _ChipPainter(
                                _flow,
                                slots: _slots,
                                vertical: vertical,
                                fill: dark
                                    ? Color.alphaBlend(
                                        nb.pandan.withValues(alpha: 0.24),
                                        nb.mist,
                                      )
                                    : nb.mist,
                                border: nb.pandan.withValues(
                                  alpha: dark ? 0.55 : 0.25,
                                ),
                              ),
                            ),
                          ),
                        ),
                        vertical
                            ? Column(children: slots)
                            : Row(children: slots),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip's two ends, in slots along the bar (at rest on a tab: [start] = its slot, [end] = the next). Each has
/// its own spring: the end facing the move is quick and leads, the other follows slower and wobbles a little as it
/// lands, so the chip stretches towards the tab and its tail catches up, like a drop of water. Stepped on one
/// ticker towards a target that may move every frame (a drag): a spring simulation restarted on each move would
/// start again from its time 0 every frame and stand still under the finger.
class _Flow extends ChangeNotifier {
  _Flow(TickerProvider vsync, double slot)
    : start = slot,
      end = slot + 1,
      _to = slot {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double start, end;
  double _vStart = 0, _vEnd = 0;
  double _to;
  bool _forward = true;
  bool _held = false;
  Duration? _last;

  static const _lead = (stiffness: 700.0, ratio: 0.8);
  static const _trail = (stiffness: 260.0, ratio: 0.68);

  /// [held]: a finger drags the chip. The end facing the move stays at the finger (no lag under it) and only the
  /// other end flows behind, as a drop pulled along. The end that leads is the one on the target's side of the
  /// chip's middle: a finger's small step back never swaps them (they swap only once the chip has caught up).
  void moveTo(double slot, {required bool still, bool held = false}) {
    _forward = slot + 0.5 > (start + end) / 2;
    _to = slot;
    _held = held;
    if (still) {
      start = slot;
      end = slot + 1;
      _vStart = _vEnd = 0;
      _ticker.stop();
      notifyListeners();
      return;
    }
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    // A ticker's first tick says 0: count it as one frame. After a stall the springs catch up with the clock (a
    // capped step would leave the chip behind), up to a second (back from the background).
    final last = _last;
    final dt = last == null
        ? 1 / 60
        : ((now - last).inMicroseconds / 1e6).clamp(0.0, 1.0);
    _last = now;
    if (dt == 0) return;
    if (_held && _forward) {
      _vEnd = (_to + 1 - end) / dt;
      end = _to + 1;
    } else {
      final (x, v) = _step(end, _vEnd, _to + 1, _forward ? _lead : _trail, dt);
      end = x;
      _vEnd = v;
    }
    if (_held && !_forward) {
      _vStart = (_to - start) / dt;
      start = _to;
    } else {
      final (x, v) = _step(start, _vStart, _to, _forward ? _trail : _lead, dt);
      start = x;
      _vStart = v;
    }
    if ((start - _to).abs() < 1e-3 &&
        (end - _to - 1).abs() < 1e-3 &&
        _vStart.abs() < 1e-2 &&
        _vEnd.abs() < 1e-2) {
      start = _to;
      end = _to + 1;
      _vStart = _vEnd = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  /// One spring (mass 1) moved on by [dt] seconds, in steps of at most 4 ms (semi-implicit Euler: stable and
  /// close enough at these stiffnesses).
  static (double, double) _step(
    double x,
    double v,
    double to,
    ({double stiffness, double ratio}) s,
    double dt,
  ) {
    final damping = 2 * s.ratio * sqrt(s.stiffness);
    for (var left = dt; left > 0; left -= 0.004) {
      final h = left < 0.004 ? left : 0.004;
      v += (s.stiffness * (to - x) - damping * v) * h;
      x += v * h;
    }
    return (x, v);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Paints [FloatingNav]'s chip from its two ends. Stretched it thins as a drop does (its width goes as
/// 1 / sqrt(its length): at twice a tab's length, ~70% as thick); squeezed as its tail lands it keeps the bar's
/// thickness; an overshoot past the bar's ends is not drawn.
class _ChipPainter extends CustomPainter {
  _ChipPainter(
    this._flow, {
    required this.slots,
    required this.vertical,
    required this.fill,
    required this.border,
  }) : super(repaint: _flow);

  final _Flow _flow;
  final int slots;
  final bool vertical;
  final Color fill;
  final Color border;

  /// Where the chip is in a canvas of [size] (the bar).
  Rect rectIn(Size size) {
    final w = (vertical ? size.height : size.width) / slots;
    final cross = vertical ? size.width : size.height;
    final from = _flow.start.clamp(0.0, slots - 0.5);
    final length = (_flow.end.clamp(0.0, slots.toDouble()) - from).clamp(
      0.5,
      slots.toDouble(),
    );
    final thin = cross * (1 - 1 / sqrt(length.clamp(1.0, 2.0))) / 2;
    return vertical
        ? Rect.fromLTWH(thin, from * w, cross - 2 * thin, length * w)
        : Rect.fromLTWH(from * w, thin, length * w, cross - 2 * thin);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = rectIn(size);
    final pill = RRect.fromRectAndRadius(
      r,
      Radius.circular(r.shortestSide / 2),
    );
    canvas.drawRRect(pill, Paint()..color = fill);
    canvas.drawRRect(
      pill.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) =>
      old._flow != _flow ||
      old.slots != slots ||
      old.vertical != vertical ||
      old.fill != fill ||
      old.border != border;
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.item,
    required this.selected,
    required this.lit,
    required this.still,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool lit;
  final bool still;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: lit ? nb.pandanDeep : nb.inkSoft),
              duration: still ? Duration.zero : _motion,
              curve: _curve,
              builder: (_, color, _) => AnimatedScale(
                scale: lit ? 1.1 : 1,
                duration: still ? Duration.zero : _motion,
                curve: _curve,
                child: switch (item.picture) {
                  final picture? => Container(
                    width: 26,
                    height: 26,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color!, width: lit ? 2 : 1),
                    ),
                    child: picture,
                  ),
                  null => Icon(
                    lit ? item.selectedIcon : item.icon,
                    size: 22,
                    color: color,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+": a round pandan button, so it never reads as a tab.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Center(
      child: Tooltip(
        message: label,
        child: Material(
          key: const ValueKey('nav-add'),
          color: nb.pandan,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: nb.ink.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 38,
              child: Icon(Icons.add, color: nb.paper, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where [FloatingNav]'s chip is drawn (its `nav-chip` CustomPaint's [painter] in a canvas of [size]).
@visibleForTesting
Rect navChipRect(CustomPainter painter, Size size) =>
    (painter as _ChipPainter).rectIn(size);
