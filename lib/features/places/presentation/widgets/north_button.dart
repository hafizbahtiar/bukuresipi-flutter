import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_theme.dart';

/// Points to north as the map turns (the map needs trackCameraPosition); tap to turn the map back, north up.
class NorthButton extends StatelessWidget {
  const NorthButton({super.key, required this.map, required this.tooltip});

  final MapLibreMapController map;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return ListenableBuilder(
      listenable: map,
      builder: (context, _) {
        final bearing = map.cameraPosition?.bearing ?? 0;
        return Tooltip(
          message: tooltip,
          child: Material(
            color: nb.paper,
            elevation: 2,
            shadowColor: nb.ink.withValues(alpha: 0.3),
            shape: CircleBorder(side: BorderSide(color: nb.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => map.animateCamera(CameraUpdate.bearingTo(0)),
              // 48 across, a 22 arrow: room for it at any angle.
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: Transform.rotate(
                    angle: -bearing * pi / 180,
                    child: Icon(Icons.navigation, size: 22, color: nb.margin),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
