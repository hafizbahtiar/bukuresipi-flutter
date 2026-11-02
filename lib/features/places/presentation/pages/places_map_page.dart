import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import 'places_list_page.dart';

/// OpenFreeMap: free vector tiles, no key, no request cap; its style carries the OpenStreetMap attribution.
const _style = 'https://tiles.openfreemap.org/styles/liberty';
const _malaysia = CameraPosition(target: LatLng(4.2, 102.0), zoom: 4.6);

/// The box around every pinned branch; null when nothing has a pin.
LatLngBounds? pinBounds(List<Place> places) {
  final pins = [for (final p in places) ...p.pins];
  if (pins.isEmpty) return null;
  double s = 90, w = 180, n = -90, e = -180;
  for (final b in pins) {
    if (b.lat! < s) s = b.lat!;
    if (b.lat! > n) n = b.lat!;
    if (b.lng! < w) w = b.lng!;
    if (b.lng! > e) e = b.lng!;
  }
  return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
}

/// The Map tab: one pin per branch with coordinates. Places without one are listed from the card at the bottom.
class PlacesMapPage extends StatefulWidget {
  const PlacesMapPage({super.key});

  @override
  State<PlacesMapPage> createState() => _PlacesMapPageState();
}

class _PlacesMapPageState extends State<PlacesMapPage> {
  MapLibreMapController? _map;
  bool _styled = false;
  late final PlacesController _places = context.read<PlacesController>();

  @override
  void initState() {
    super.initState();
    _places.addListener(_draw);
  }

  @override
  void dispose() {
    _places.removeListener(_draw);
    _map?.onCircleTapped.remove(_tapped);
    super.dispose();
  }

  void _created(MapLibreMapController c) {
    _map = c..onCircleTapped.add(_tapped);
  }

  Future<void> _styleLoaded() async {
    _styled = true;
    await _draw(fit: true);
  }

  /// Redraws every pin (a handful per user: no diffing needed).
  Future<void> _draw({bool fit = false}) async {
    final map = _map;
    if (map == null || !_styled) return;
    final places = _places.pinned;
    await map.clearCircles();
    await map.addCircles(
      [
        for (final p in places)
          for (final b in p.pins)
            CircleOptions(
              geometry: LatLng(b.lat!, b.lng!),
              circleRadius: 8,
              circleColor: '#2F6B3B',
              circleStrokeWidth: 2.5,
              circleStrokeColor: '#FFFFFF',
            ),
      ],
      [
        for (final p in places)
          for (final _ in p.pins) {'place': p.id},
      ],
    );
    if (!fit) return;
    final box = pinBounds(places);
    if (box == null) return;
    final single = box.southwest == box.northeast;
    await map.moveCamera(
      single
          ? CameraUpdate.newLatLngZoom(box.southwest, 14)
          : CameraUpdate.newLatLngBounds(
              box,
              left: 48,
              top: 48,
              right: 48,
              bottom: 120,
            ),
    );
  }

  void _tapped(Circle c) {
    final place = _places.byId(c.data?['place'] as String? ?? '');
    if (place == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PlaceTile(place: place),
        ),
      ),
    );
  }

  void _showUnpinned(List<Place> unpinned) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l.unpinnedHelp,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final p in unpinned) PlaceTile(place: p),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final places = context.watch<PlacesController>();
    final unpinned = places.unpinned;
    return Scaffold(
      appBar: AppBar(title: Text(l.navMap), actions: const [AccountButton()]),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _style,
            initialCameraPosition: _malaysia,
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.topRight,
          ),
          if (places.loaded && places.pinned.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _Note(text: l.mapEmpty),
            ),
          if (unpinned.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_off_outlined),
                    title: Text(l.unpinnedTitle),
                    trailing: CircleAvatar(
                      radius: 14,
                      child: Text('${unpinned.length}'),
                    ),
                    onTap: () => _showUnpinned(unpinned),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
