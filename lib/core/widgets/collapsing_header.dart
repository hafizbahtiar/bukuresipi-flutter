import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

const _motion = Duration(milliseconds: 260);
const _curve = Curves.easeOutCubic;

/// A header above a list that folds away when the list scrolls down and comes back when it scrolls up, in the app's
/// motion (260 ms, easeOutCubic; instant when the phone asks for no motion). The header keeps its natural height, so a
/// long title or a larger text size still fits. Put it above the scrollable whose [controller] it watches.
class CollapsingHeader extends StatefulWidget {
  const CollapsingHeader({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<CollapsingHeader> createState() => _CollapsingHeaderState();
}

class _CollapsingHeaderState extends State<CollapsingHeader>
    with SingleTickerProviderStateMixin {
  // 1 = open, 0 = folded away.
  late final _open = AnimationController(
    vsync: this,
    duration: _motion,
    value: 1,
  );
  ScrollDirection _last = ScrollDirection.idle;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant CollapsingHeader old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _open.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (position.userScrollDirection == _last) return;
    _last = position.userScrollDirection;
    // Down folds it away (not while the list is still at the top); up brings it back.
    if (_last == ScrollDirection.reverse && position.pixels > 0) {
      _to(0);
    } else if (_last == ScrollDirection.forward) {
      _to(1);
    }
  }

  void _to(double value) {
    if (_open.value == value) return;
    if (_still) {
      _open.value = value;
    } else {
      _open.animateTo(value, duration: _motion, curve: _curve);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _open,
    child: widget.child,
    builder: (context, child) => ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: _open.value,
        child: child,
      ),
    ),
  );
}
