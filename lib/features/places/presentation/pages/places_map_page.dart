import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/north_button.dart';
import '../widgets/unpinned_actions.dart';
import 'places_list_page.dart';

/// OpenFreeMap: free vector tiles, no key, no request cap; its style carries the OpenStreetMap attribution.
const _style = 'https://tiles.openfreemap.org/styles/liberty';
const malaysiaCamera = CameraPosition(target: LatLng(4.2, 102.0), zoom: 4.6);
const mapStyle = _style;

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

/// The Map tab: one pin per branch with coordinates (rotate with two fingers; the north button turns it back).
/// Places without a pin are listed from the slip at the bottom, each with "Find location" / "Set on map".
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
    setState(() => _map = c..onCircleTapped.add(_tapped));
  }

  Future<void> _styleLoaded() async {
    _styled = true;
    await _draw(fit: true);
  }

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Redraws every pin (a handful per user: no diffing needed). A hand-set pin has a kunyit ring: not checked yet.
  Future<void> _draw({bool fit = false}) async {
    final map = _map;
    if (map == null || !_styled || !mounted) return;
    final nb = Notebook.of(context);
    final places = _places.pinned;
    await map.clearCircles();
    final pins = [
      for (final p in places)
        for (final b in p.pins) (p, b),
    ];
    await map.addCircles(
      [
        for (final (_, b) in pins)
          CircleOptions(
            geometry: LatLng(b.lat!, b.lng!),
            circleRadius: 8,
            circleColor: _hex(nb.pandan),
            circleStrokeWidth: 3,
            circleStrokeColor: b.pinnedByUser ? _hex(nb.kunyit) : '#FFFFFF',
          ),
      ],
      [
        for (final (p, _) in pins) {'place': p.id},
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
              top: 64,
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

  void _showUnpinned() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          // Rebuilds as places get pinned: a found place leaves this list.
          child: Consumer<PlacesController>(
            builder: (context, places, _) {
              final text = Theme.of(context).textTheme;
              return NotebookPage(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        notebookGutter + 10,
                        0,
                        20,
                        12,
                      ),
                      child: Text(
                        l.unpinnedHelp,
                        style: text.bodyMedium?.copyWith(
                          color: Notebook.of(context).inkSoft,
                        ),
                      ),
                    ),
                    for (final p in places.unpinned)
                      NotebookRow(
                        mark: const PinMark(pinned: false),
                        onTap: () => context.push('/places/${p.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.restaurant.name,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (p.savedBranch case final b?) ...[
                              if (b.label != null &&
                                  b.label != p.restaurant.name)
                                Text(b.label!, style: text.bodySmall),
                              UnpinnedActions(place: p, branch: b),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final places = context.watch<PlacesController>();
    final unpinned = places.unpinned.length;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.navMap)),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: mapStyle,
            initialCameraPosition: malaysiaCamera,
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            tiltGesturesEnabled: false,
            compassEnabled: false, // our own north button: always there, on the notebook's paper
            trackCameraPosition: true,
            logoEnabled: false,
            // The credit OpenStreetMap needs stays, as a faint "i" in the corner.
            attributionButtonPosition: AttributionButtonPosition.topLeft,
            attributionButtonMargins: const Point(8, 8),
            attributionButtonColor: nb.ink.withValues(alpha: 0.3),
          ),
          if (_map != null)
            Positioned(
              top: 12,
              right: 12,
              child: NorthButton(
                map: _map!,
                tooltip: AppLocalizations.of(context).northUp,
              ),
            ),
          if (places.loaded && places.pinned.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 48,
              child: _Slip(
                child: Text(l.mapEmpty, textAlign: TextAlign.center),
              ),
            ),
          if (unpinned > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: _Slip(
                  onTap: _showUnpinned,
                  child: Row(
                    children: [
                      const PinMark(pinned: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l.unpinnedCount(unpinned),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.expand_less, color: nb.inkSoft),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A slip of paper laid on the map.
class _Slip extends StatelessWidget {
  const _Slip({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Material(
      color: nb.paper,
      elevation: 2,
      shadowColor: nb.ink.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: nb.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );
  }
}
