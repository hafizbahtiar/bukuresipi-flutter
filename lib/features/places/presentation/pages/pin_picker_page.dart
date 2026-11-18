import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../location.dart';
import '../places_controller.dart';
import '../widgets/location_button.dart';
import '../widgets/north_button.dart';
import 'places_map_page.dart';

/// Set a branch's pin by hand, Google Maps style: the pin stays in the middle and the map moves under it. One pin
/// per user per branch on the server (moving it again replaces it).
class PinPickerPage extends StatefulWidget {
  const PinPickerPage({
    super.key,
    required this.placeId,
    required this.branchId,
    this.initial,
    this.resultOnly = false,
  });

  final String placeId;
  final String branchId;

  /// Start here when the branch is not in the caller's saved places yet.
  final LatLng? initial;

  /// Return the chosen point to the caller instead of saving a user hand pin (owner branch edit).
  final bool resultOnly;

  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  MapLibreMapController? _map;
  LatLng? _pin;
  bool _saving = false;
  bool _locating = false;
  bool _started = false;

  /// Where the map opens. Null while looking for the user: the map waits instead of opening on all of Malaysia.
  CameraPosition? _camera;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _camera = _start(context.read<PlacesController>());
    if (_camera == null) {
      _openAtUser();
    } else {
      _pin = _camera!.target;
    }
  }

  Future<void> _openAtUser() async {
    final here = await startPosition();
    if (!mounted) return;
    setState(() {
      _camera = here == null
          ? malaysiaCamera
          : CameraPosition(target: LatLng(here.lat, here.lng), zoom: 17);
      _pin = _camera!.target;
    });
  }

  void _created(MapLibreMapController c) {
    setState(() => _map = c);
  }

  Future<void> _styleLoaded() async {
    _cameraIdle();
  }

  /// The pin is painted at the centre of the map, so the camera target is the chosen point.
  void _cameraIdle() {
    final target = _map?.cameraPosition?.target;
    if (target != null && mounted) setState(() => _pin = target);
  }

  /// The branch being edited when it has a pin, else a pinned branch of the same restaurant, else null (the user's
  /// location, then Malaysia).
  CameraPosition? _start(PlacesController places) {
    final place = places.byId(widget.placeId);
    final branch = place?.branches
        .where((b) => b.id == widget.branchId)
        .firstOrNull;
    if (branch?.hasPin ?? false) {
      return CameraPosition(
        target: LatLng(branch!.lat!, branch.lng!),
        zoom: 16,
      );
    }
    if (widget.initial case final initial?) {
      return CameraPosition(target: initial, zoom: 16);
    }
    final pins = place?.pins ?? const [];
    return pins.isEmpty
        ? null
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
      final here = await currentPosition();
      if (here == null) {
        messenger.showSnackBar(SnackBar(content: Text(l.locationDenied)));
        return;
      }
      final target = LatLng(here.latitude, here.longitude);
      if (mounted) setState(() => _pin = target);
      await quietMap(
        _map?.animateCamera(CameraUpdate.newLatLngZoom(target, 18)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.locationDenied)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final target = _pin ?? _map?.cameraPosition?.target;
    if (target == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (widget.resultOnly) {
      navigator.pop(target);
      return;
    }
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
                if (_camera == null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: nb.paper,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator.adaptive(),
                            const SizedBox(height: 12),
                            Text(
                              l.pinFindingYou,
                              style: text.bodyMedium?.copyWith(
                                color: nb.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  MapLibreMap(
                    styleString: mapStyle(context),
                    initialCameraPosition: _camera!,
                    onMapCreated: _created,
                    onStyleLoadedCallback: _styleLoaded,
                    onCameraIdle: _cameraIdle,
                    trackCameraPosition: true,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                    logoEnabled: false,
                    attributionButtonPosition:
                        AttributionButtonPosition.topLeft,
                    attributionButtonMargins: const Point(8, 8),
                    attributionButtonColor: nb.ink.withValues(alpha: 0.3),
                  ),
                // Google Maps style: the pin is fixed to the middle; the map moves underneath.
                if (_camera != null)
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: const Offset(0, -24),
                        child: Icon(
                          Icons.location_pin,
                          size: 48,
                          color: nb.margin,
                          shadows: [
                            Shadow(
                              color: nb.ink.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_map != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ListenableBuilder(
                      listenable: _map!,
                      builder: (context, _) => NorthButton(
                        bearing: _map!.cameraPosition?.bearing ?? 0,
                        tooltip: AppLocalizations.of(context).northUp,
                        onPressed: () => quietMap(
                          _map!.animateCamera(CameraUpdate.bearingTo(0)),
                        ),
                      ),
                    ),
                  ),
                if (_camera != null)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: LocationButton(
                      tooltip: l.myLocation,
                      onPressed: _myLocation,
                      busy: _locating,
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
                  if (_pin case final pin?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${pin.latitude.toStringAsFixed(6)}, ${pin.longitude.toStringAsFixed(6)}',
                        style: text.bodySmall?.copyWith(
                          color: nb.inkSoft,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving || _pin == null ? null : _save,
                    child: Text(widget.resultOnly ? l.pinUse : l.pinSave),
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
