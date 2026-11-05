import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The my-location button, styled like the north button: paper circle on the map.
class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

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
          onTap: busy ? null : onPressed,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, size: 18, color: nb.pandanDeep),
            ),
          ),
        ),
      ),
    );
  }
}
