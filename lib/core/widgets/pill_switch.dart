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
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, Widget, String?)> options;

  /// true = the segments share the full width (tabs); false = as narrow as their content (a row's trailing).
  final bool expand;

  @override
  State<PillSwitch<T>> createState() => _PillSwitchState<T>();
}

class _PillSwitchState<T> extends State<PillSwitch<T>> {
  final _track = GlobalKey();
  late List<GlobalKey> _keys = _newKeys();

  /// The chip's place inside the track; null until the first layout is measured.
  Rect? _chip;

  /// false for the first placement (a page opens with the chip already there), true after.
  bool _slide = false;

  List<GlobalKey> _newKeys() =>
      List.generate(widget.options.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant PillSwitch<T> old) {
    super.didUpdateWidget(old);
    if (old.options.length != widget.options.length) _keys = _newKeys();
  }

  // After every layout: where the chosen option sits now (a tap, a resize, a new language's wider label).
  void _measure() {
    if (!mounted) return;
    final track = _track.currentContext?.findRenderObject() as RenderBox?;
    final i = widget.options.indexWhere((o) => o.$1 == widget.value);
    final box = i < 0
        ? null
        : _keys[i].currentContext?.findRenderObject() as RenderBox?;
    if (track == null || box == null || !track.hasSize || !box.hasSize) {
      return;
    }
    final rect = box.localToGlobal(Offset.zero, ancestor: track) & box.size;
    if (rect == _chip) return;
    setState(() {
      _slide = _chip != null;
      _chip = rect;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final nb = Notebook.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    // Dark paper is darker than mist, so the chip takes the lighter line colour there (else it looks sunk in).
    final chipColor = Theme.of(context).brightness == Brightness.dark
        ? nb.line
        : nb.paper;
    final chip = _chip;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: nb.line),
      ),
      child: Stack(
        key: _track,
        children: [
          if (chip != null)
            AnimatedPositioned(
              duration: _slide && !still ? _motion : Duration.zero,
              curve: _curve,
              left: chip.left,
              top: chip.top,
              width: chip.width,
              height: chip.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: nb.ink.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final (i, (code, shown, name)) in widget.options.indexed)
                _segment(
                  Semantics(
                    button: true,
                    selected: code == widget.value,
                    label: name,
                    child: GestureDetector(
                      key: _keys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onChanged(code),
                      child: _Option(
                        selected: code == widget.value,
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
