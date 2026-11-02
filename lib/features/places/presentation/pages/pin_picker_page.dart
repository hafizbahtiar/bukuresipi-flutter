import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../places_controller.dart';
import 'places_map_page.dart';

/// Set a branch's pin by hand: move the map under a fixed pin, or jump to where you stand. One pin per user per
/// branch on the server (moving it again replaces it).
class PinPickerPage extends StatefulWidget {
  const PinPickerPage({
    super.key,
    required this.placeId,
    required this.branchId,
  });

  final String placeId;
  final String branchId;

  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  MapLibreMapController? _map;
  bool _saving = false;
  bool _locating = false;

  /// Near a pinned branch of the same restaurant when there is one, else all of Malaysia.
  CameraPosition _start(PlacesController places) {
    final pins = places.byId(widget.placeId)?.pins ?? const [];
    return pins.isEmpty
        ? malaysiaCamera
        : CameraPosition(
            target: LatLng(pins.first.lat!, pins.first.lng!),
            zoom: 13,
          );
  }

  Future<void> _myLocation() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(SnackBar(content: Text(l.locationDenied)));
        return;
      }
      final here = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(here.latitude, here.longitude), 18),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.locationDenied)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final target = _map?.cameraPosition?.target;
    if (target == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await context.read<PlacesController>().setPin(
        widget.branchId,
        target.latitude,
        target.longitude,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.pinSaved)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.pinPickTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MapLibreMap(
                  styleString: mapStyle,
                  initialCameraPosition: _start(
                    context.read<PlacesController>(),
                  ),
                  onMapCreated: (c) => _map = c,
                  trackCameraPosition: true,
                  tiltGesturesEnabled: false,
                  compassEnabled: true,
                  compassViewPosition: CompassViewPosition.topRight,
                  compassViewMargins: const Point(12, 12),
                  logoEnabled: false,
                  attributionButtonPosition: AttributionButtonPosition.topLeft,
                  attributionButtonMargins: const Point(8, 8),
                  attributionButtonColor: nb.ink.withValues(alpha: 0.3),
                ),
                // The fixed pin: its tip marks the map's centre.
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: nb.margin,
                      shadows: [
                        Shadow(
                          color: nb.ink.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: l.myLocation,
                    backgroundColor: nb.paper,
                    foregroundColor: nb.pandanDeep,
                    onPressed: _locating ? null : _myLocation,
                    child: _locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.pinPickHint,
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l.pinSave),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
