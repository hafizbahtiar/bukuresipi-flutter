import 'dart:async';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _motion = Duration(milliseconds: 260);
const _curve = Curves.easeOutCubic;

/// A pill track of options, the chosen one a raised chip that slides (and resizes) to the option tapped: Settings'
/// language and theme, a recipe's tabs, the Receipts tab and a receipt's Receipt | Split bill.
/// Each option is (value, what it shows, tooltip + screen-reader name or null when what it shows is text).
class PillSwitch<T> extends StatefulWidget {
  const PillSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
    this.expand = false,
    this.pages,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, Widget, String?)> options;

  /// true = the segments share the full width (tabs); false = as narrow as their content (a row's trailing).
  final bool expand;

  /// The [PageView] of the options' content, one page per option in order. Given, the chip follows the pages while
  /// they are swiped, dragging the pill drags the pages, and a tap animates to the page: the PageView's
  /// onPageChanged then reports the change ([onChanged] is not called).
  final PageController? pages;

  @override
  State<PillSwitch<T>> createState() => _PillSwitchState<T>();
}

class _PillSwitchState<T> extends State<PillSwitch<T>> {
  final _track = GlobalKey();
  late List<GlobalKey> _keys = _newKeys();

  /// Each option's place inside the track; null until the first layout is measured.
  List<Rect>? _rects;

  /// false for the first placement (a page opens with the chip already there), true after.
  bool _slide = false;

  List<GlobalKey> _newKeys() =>
      List.generate(widget.options.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant PillSwitch<T> old) {
    super.didUpdateWidget(old);
    if (old.options.length != widget.options.length) {
      _keys = _newKeys();
      _rects = null;
    }
    if (old.value != widget.value) {
      _landing = null; // the parent caught up
      _giveUp?.cancel();
    }
  }

  int get _index => widget.options.indexWhere((o) => o.$1 == widget.value);

  /// Without pages: the option just picked, while the parent saves it (a theme, a language) and before [value]
  /// says so. The chip goes straight there instead of back to the old option first.
  int? _landing;
  Timer? _giveUp;

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  /// The option the chip shows: the one landing, else [value]'s.
  int get _shown => _landing ?? _index;

  void _pick(int i) {
    if (i == _index) {
      if (_landing != null) setState(() => _landing = null);
      return;
    }
    setState(() => _landing = i);
    widget.onChanged(widget.options[i].$1);
    // A parent that keeps the old value (refused, or changed its mind): the chip goes back once it settles.
    _giveUp?.cancel();
    _giveUp = Timer(_motion * 3, () {
      if (mounted && _landing == i) setState(() => _landing = null);
    });
  }

  // After every layout: where each option sits now (a tap, a resize, a new language's wider label).
  void _measure() {
    if (!mounted) return;
    final track = _track.currentContext?.findRenderObject() as RenderBox?;
    if (track == null || !track.hasSize) return;
    final rects = <Rect>[];
    for (final k in _keys) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      rects.add(box.localToGlobal(Offset.zero, ancestor: track) & box.size);
    }
    final old = _rects;
    if (old != null &&
        old.length == rects.length &&
        [for (var i = 0; i < rects.length; i++) old[i] == rects[i]]
            .every((x) => x)) {
      return;
    }
    setState(() {
      _slide = old != null;
      _rects = rects;
    });
  }

  /// The chip between two options while the pages are mid-swipe.
  Rect _chipAt(List<Rect> rects, double page) {
    final p = page.clamp(0, rects.length - 1).toDouble();
    final i = p.floor();
    final j = p.ceil();
    return Rect.lerp(rects[i], rects[j], p - i)!;
  }

  bool get _hasPages => widget.pages?.hasClients ?? false;

  /// Without pages: where the dragged chip is, in options (1.5 = halfway between the 2nd and 3rd); null at rest.
  double? _dragAt;

  /// Where a released drag settles: a flick goes on to the next option in its direction, else the nearest.
  int _settle(double at, double velocity) {
    final target = velocity.abs() > 300
        ? (velocity > 0 ? at.floor() + 1 : at.ceil() - 1)
        : at.round();
    return target.clamp(0, widget.options.length - 1);
  }

  void _tap(int i, T code) {
    final pages = widget.pages;
    if (pages == null || !pages.hasClients) return _pick(i);
    if (MediaQuery.disableAnimationsOf(context)) return pages.jumpToPage(i);
    pages.animateToPage(i, duration: _motion, curve: _curve);
  }

  // Dragging the pill: the chip moves under the finger and the pages with it (one option = one page).
  void _drag(DragUpdateDetails d) {
    final rects = _rects;
    if (rects == null || rects.length < 2) return;
    final step = rects[1].center.dx - rects[0].center.dx;
    if (!_hasPages) {
      // No pages: the chip itself follows the finger; the option is picked on release.
      setState(
        () => _dragAt = ((_dragAt ?? _index.toDouble()) + d.delta.dx / step)
            .clamp(0, rects.length - 1)
            .toDouble(),
      );
      return;
    }
    final pos = widget.pages!.position;
    pos.jumpTo(
      (pos.pixels + d.delta.dx * pos.viewportDimension / step).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      ),
    );
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (!_hasPages) {
      final at = _dragAt;
      if (at == null) return;
      final to = _settle(at, v);
      // The chip slides from the finger straight to the option, in the same frame it is picked.
      setState(() => _dragAt = null);
      _pick(to);
      return;
    }
    final to = _settle(widget.pages!.page ?? _index.toDouble(), v);
    _tap(to, widget.options[to].$1);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final nb = Notebook.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    // Dark: a shadow does not show on dark paper, and the line colour was too close to the track's mist (only the
    // shadow read), so the chip is the track tinted with pandan, with a pandan edge. Light: white paper, raised.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = dark
        ? Color.alphaBlend(nb.pandan.withValues(alpha: 0.24), nb.mist)
        : nb.paper;
    final rects = _rects;
    final sel = _shown;
    final chipBox = DecoratedBox(
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
        border: dark
            ? Border.all(color: nb.pandan.withValues(alpha: 0.55))
            : null,
        boxShadow: [
          BoxShadow(
            color: nb.ink.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
    final pages = widget.pages;
    final track = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: nb.line),
      ),
      child: Stack(
        key: _track,
        children: [
          if (rects != null && pages != null)
            // Follows the pages frame by frame: no animation of its own.
            AnimatedBuilder(
              animation: pages,
              builder: (_, child) => Positioned.fromRect(
                rect: _chipAt(
                  rects,
                  pages.hasClients && pages.position.hasContentDimensions
                      ? pages.page ?? sel.toDouble()
                      : sel.toDouble(),
                ),
                child: child!,
              ),
              child: chipBox,
            )
          else if (rects != null && sel >= 0)
            Builder(
              builder: (_) {
                final at = _dragAt;
                final r = at == null ? rects[sel] : _chipAt(rects, at);
                return AnimatedPositioned(
                  // Under the finger: no lag. Released or tapped: it slides.
                  duration: at != null || !_slide || still
                      ? Duration.zero
                      : _motion,
                  curve: _curve,
                  left: r.left,
                  top: r.top,
                  width: r.width,
                  height: r.height,
                  child: chipBox,
                );
              },
            ),
          Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final (i, (code, shown, name)) in widget.options.indexed)
                _segment(
                  Semantics(
                    button: true,
                    selected: i == sel,
                    label: name,
                    child: GestureDetector(
                      key: _keys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _tap(i, code),
                      child: _Option(
                        selected: i == sel,
                        still: still,
                        name: name,
                        child: shown,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return GestureDetector(
      // From the touch, so the chip stays under the finger.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: _dragEnd,
      onHorizontalDragCancel: () => setState(() => _dragAt = null),
      child: track,
    );
  }

  Widget _segment(Widget child) =>
      widget.expand ? Expanded(child: child) : child;
}

/// One option's label. Its colour fades to the chosen one; the weight changes at once (a weight that animated would
/// change the label's width under the chip mid-slide).
class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.still,
    required this.name,
    required this.child,
  });

  final bool selected;
  final bool still;
  final String? name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          widthFactor: 1,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: selected ? nb.pandanDeep : nb.inkSoft),
            duration: still ? Duration.zero : _motion,
            curve: _curve,
            builder: (context, color, _) => IconTheme.merge(
              data: IconThemeData(size: 18, color: color),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: name == null
                    ? child
                    : Tooltip(
                        message: name,
                        child: ExcludeSemantics(child: child),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon and a short label, for a [PillSwitch] option.
class PillLabel extends StatelessWidget {
  const PillLabel(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}
