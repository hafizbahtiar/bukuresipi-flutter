import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The 3D/2D button, styled like the north button: paper circle on the map.
class ViewModeButton extends StatelessWidget {
  const ViewModeButton({
    super.key,
    required this.threeD,
    required this.tooltip,
    required this.onPressed,
  });

  final bool threeD;
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
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Text(
                threeD ? '2D' : '3D',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: nb.pandanDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
