import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Points to north on the map. The page feeds [bearing] after the camera settles, so gestures stay free of
/// per-frame widget rebuilds; tap to turn the map back, north up.
class NorthButton extends StatelessWidget {
  const NorthButton({
    super.key,
    required this.bearing,
    required this.tooltip,
    required this.onPressed,
  });

  final double bearing;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: nb.paper,
        elevation: 2,
        shadowColor: nb.ink.withValues(alpha: 0.3),
        shape: CircleBorder(side: BorderSide(color: nb.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          // 40 across, an 18 compass: room for it at any angle.
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Transform.rotate(
                angle: -bearing * pi / 180,
                child: Icon(Icons.explore, size: 18, color: nb.margin),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
