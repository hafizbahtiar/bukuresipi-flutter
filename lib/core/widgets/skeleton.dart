import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A loading placeholder: [child]'s [SkeletonBox]es with a soft light sweeping across them, left to right. Only the
/// boxes shimmer (what is under them, a card's paper, stays still). Still with reduced motion. Hidden from screen
/// readers: a loading list says nothing until it has something.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final base = nb.line;
    final light = Color.lerp(nb.line, nb.paper, 0.7)!;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) => ShaderMask(
          // srcATop: the gradient paints only where a box is.
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t =
                _sweep.value * 2 -
                0.5; // -0.5..1.5: starts and ends off the edge
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, light, base],
              stops: [
                t - 0.3,
                t,
                t + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// One grey shape inside a [Skeleton]: a line of text, a photo, a button.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius});

  final double? width;
  final double height;

  /// Default: a text line's rounded ends.
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Notebook.of(context).line,
      borderRadius: BorderRadius.circular(radius ?? height / 2),
    ),
  );
}

/// A list still loading: [rows] grey rows shaped like the ListTiles that will replace them (icon, two lines,
/// an amount at the end).
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 40, height: 40, radius: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.7 : 0.55,
                        child: const SkeletonBox(height: 14),
                      ),
                      const SizedBox(height: 8),
                      const FractionallySizedBox(
                        widthFactor: 0.4,
                        child: SkeletonBox(height: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const SkeletonBox(width: 56, height: 14),
              ],
            ),
          ),
      ],
    ),
  );
}
