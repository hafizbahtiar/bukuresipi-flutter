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
        return FloatingActionButton.small(
          heroTag: null,
          tooltip: tooltip,
          backgroundColor: nb.paper,
          foregroundColor: nb.margin,
          onPressed: () => map.animateCamera(CameraUpdate.bearingTo(0)),
          child: Transform.rotate(
            angle: -bearing * pi / 180,
            child: const Icon(Icons.navigation),
          ),
        );
      },
    );
  }
}
