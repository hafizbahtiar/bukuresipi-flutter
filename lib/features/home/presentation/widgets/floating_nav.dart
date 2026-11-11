import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

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
/// on a chip that slides to a tapped tab, and can be dragged along the bar like a [PillSwitch]'s: let go and it
/// settles on the nearest tab (a flick goes on in its direction). "+" is a round button in the middle, not a tab:
/// the chip passes it by.
class FloatingNav extends StatefulWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.addLabel,
    required this.onAdd,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;

  static const height = 56.0;

  @override
  State<FloatingNav> createState() => _FloatingNavState();
}

class _FloatingNavState extends State<FloatingNav> {
  /// The chip's place in slots while a finger drags it; null = resting on the selected tab.
  double? _drag;

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
    final tab = _tabOf(_settle(at, d.primaryVelocity ?? 0));
    setState(() => _drag = null);
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
    const radius = BorderRadius.all(Radius.circular(28));
    // Under the finger the nearest tab lights up; at rest, the selected one.
    final lit = switch (_drag) {
      final at? => _settle(at, 0),
      null => _slotOf(widget.selected),
    };
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: nb.ink.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: FloatingNav.height,
              padding: const EdgeInsets.all(2),
              // Glass: a thin tint over the blurred page, brighter at the top like light on a pane, and a
              // light rim instead of a drawn border.
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    nb.paper.withValues(alpha: dark ? 0.62 : 0.58),
                    nb.paper.withValues(alpha: dark ? 0.46 : 0.38),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.10 : 0.65),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth / _slots;
                  final chipAt = _drag ?? _slotOf(widget.selected).toDouble();
                  return GestureDetector(
                    // From the touch, not from where the drag was recognised: the chip stays under the finger.
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragStart: (_) => setState(
                      () => _drag = _slotOf(widget.selected).toDouble(),
                    ),
                    onHorizontalDragUpdate: (d) => setState(
                      () => _drag = ((_drag ?? 0) + d.delta.dx / w).clamp(
                        0,
                        _slots - 1,
                      ),
                    ),
                    onHorizontalDragEnd: _dragEnd,
                    onHorizontalDragCancel: () => setState(() => _drag = null),
                    child: Stack(
                      children: [
                        // The chip: follows the finger while dragged, slides when a tab is picked.
                        AnimatedPositioned(
                          key: const ValueKey('nav-chip'),
                          duration: _drag != null || still
                              ? Duration.zero
                              : _motion,
                          curve: _curve,
                          left: chipAt * w,
                          top: 0,
                          bottom: 0,
                          width: w,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dark
                                  ? Color.alphaBlend(
                                      nb.pandan.withValues(alpha: 0.24),
                                      nb.mist,
                                    )
                                  : nb.mist,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: nb.pandan.withValues(
                                  alpha: dark ? 0.55 : 0.25,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var s = 0; s < _slots; s++)
                              SizedBox(
                                width: w,
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
                                        onTap: () {
                                          if (_tabOf(s) != widget.selected) {
                                            widget.onSelected(_tabOf(s));
                                          }
                                        },
                                      ),
                              ),
                          ],
                        ),
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
