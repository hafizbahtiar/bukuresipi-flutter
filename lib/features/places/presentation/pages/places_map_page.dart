import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../owner/domain/owner.dart';
import '../../../owner/domain/owner_repository.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/nearby_math.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/map_search.dart';
import '../widgets/location_button.dart';
import '../widgets/branch_edit_sheet.dart';
import '../widgets/map_legend.dart';
import '../widgets/nearby_carousel.dart';
import '../widgets/nearby_sheet.dart';
import '../widgets/notebook_rating.dart';
import '../widgets/north_button.dart';
import '../widgets/unpinned_actions.dart';
import '../widgets/view_mode_button.dart';
import '../location.dart';
import '../../../shares/presentation/widgets/share_image.dart';

/// OpenFreeMap: free vector tiles, no key, no request cap; its style carries the OpenStreetMap attribution.
const _style = 'https://tiles.openfreemap.org/styles/liberty';
const malaysiaCamera = CameraPosition(target: LatLng(4.2, 102.0), zoom: 4.6);
// The "you are here" dot. Drawn by us (not the native location component) so it appears as soon as
// the permission result arrives, even when the map was created before permission was granted.
const _hereColor = '#1E88E5';
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

/// The Map tab: one pin per branch with coordinates (two fingers rotate and tilt for 3D; the north button turns
/// it back). Places without a pin are listed from the slip at the bottom, each with "Find location" / "Set on map".
class PlacesMapPage extends StatefulWidget {
  const PlacesMapPage({super.key, this.active = true});

  /// The Map tab is visible. Location tracking runs only while this and the app are active.
  final bool active;

  @override
  State<PlacesMapPage> createState() => _PlacesMapPageState();
}

class _PlacesMapPageState extends State<PlacesMapPage>
    with WidgetsBindingObserver {
  MapLibreMapController? _map;
  bool _styled = false;
  late final PlacesController _places = context.read<PlacesController>();
  List<NearbyBranch> _nearby = const [];

  /// Only the owner sees restaurants other users saved: every pinned one (GET /owner/places), switchable in the
  /// legend. Users see their own and their family's only (other users' places: later, to be designed).
  late final bool _owner =
      context.read<AuthController>().user?.isOwner ?? false;
  late bool _showCommunity = _owner;
  List<OwnerPlace> _all = const [];

  Future<void> _loadAll() async {
    if (!_owner) return;
    try {
      _all = await context.read<OwnerRepository>().places();
      if (mounted) unawaited(_draw());
    } catch (_) {
      // The owner's extra layer only; the map works without it.
    }
  }

  List<NearbyBranch> get _shownNearby => _showCommunity
      ? _nearby
      : [
          for (final n in _nearby)
            if (n.saved) n,
        ];
  String? _selectedNearbyId;
  LatLng? _here;
  LatLng? _nearbyOrigin;
  double _bearing = 0;
  double _tilt = 0;
  bool _locating = false;
  bool _askingLocation = false;
  bool _nearbyLoading = false;
  bool _nearbyAgain = false;
  bool _resumed = true;
  int _generation = 0;
  StreamSubscription<({double lat, double lng})>? _positionSub;
  Circle? _hereHalo;
  Circle? _hereDot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _places.addListener(_draw);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askLocationOnce();
      _loadAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _places.removeListener(_draw);
    _map?.onCircleTapped.remove(_tapped);
    super.dispose();
  }

  @override
  void didUpdateWidget(PlacesMapPage old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active && _resumed) {
      unawaited(_refreshLocation());
    }
    _syncLocationUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    _syncLocationUpdates();
    if (resumed && widget.active) unawaited(_refreshLocation());
  }

  void _created(MapLibreMapController c) {
    setState(() => _map = c..onCircleTapped.add(_tapped));
  }

  Future<void> _styleLoaded() async {
    _styled = true;
    await _draw(fit: _here == null);
    if (_here case final here?) {
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14));
    }
    _cameraIdle();
  }

  /// The one automatic ask when the map opens. A refusal just leaves the map as it was (no nag).
  Future<void> _askLocationOnce() async {
    if (_askingLocation) return;
    _askingLocation = true;
    try {
      final here = await _currentLocation();
      if (!mounted || here == null) return;
      // Outside Malaysia the map stays on the saved places, as before.
      if (!inMalaysia(here.latitude, here.longitude)) return;
      setState(() => _here = here);
      unawaited(_draw());
      unawaited(_loadNearby());
      _syncLocationUpdates();
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14));
      _cameraIdle();
    } finally {
      _askingLocation = false;
    }
  }

  /// A fresh fix for resume/tab-open. The dot and nearby list follow; the camera is left where the user put it.
  Future<void> _refreshLocation() async {
    if (_askingLocation || _locating) return;
    _askingLocation = true;
    try {
      final here = await _currentLocation();
      if (!mounted || here == null) return;
      if (!inMalaysia(here.latitude, here.longitude)) return;
      setState(() => _here = here);
      unawaited(_draw());
      unawaited(_loadNearby());
      _syncLocationUpdates();
    } finally {
      _askingLocation = false;
    }
  }

  /// Foreground updates only: no stream while the Map tab or the app is inactive.
  void _syncLocationUpdates() {
    final shouldTrack = widget.active && _resumed;
    if (shouldTrack && _positionSub == null) {
      try {
        _positionSub = positionUpdates().listen(
          _onPosition,
          onError: (_) {
            _positionSub?.cancel();
            _positionSub = null;
          },
          onDone: () => _positionSub = null,
        );
      } catch (_) {
        _positionSub = null;
      }
    } else if (!shouldTrack) {
      _positionSub?.cancel();
      _positionSub = null;
    }
  }

  void _onPosition(({double lat, double lng}) p) {
    if (!mounted || !inMalaysia(p.lat, p.lng)) return;
    final here = LatLng(p.lat, p.lng);
    final previous = _here;
    if (previous != null &&
        distanceKm(
                  previous.latitude,
                  previous.longitude,
                  here.latitude,
                  here.longitude,
                ) *
                1000 <
            10) {
      return;
    }
    setState(() {
      _here = here;
      if (_nearby.isNotEmpty) {
        _nearby = sortByDistanceFrom(_nearby, here.latitude, here.longitude);
      }
    });
    // Move only the two location circles; a full circle redraw is for nearby/saved changes.
    unawaited(_moveHereDot(here));
    final origin = _nearbyOrigin;
    final moved =
        origin == null ||
        distanceKm(
              origin.latitude,
              origin.longitude,
              here.latitude,
              here.longitude,
            ) >=
            0.2;
    if (moved) unawaited(_loadNearby());
  }

  Future<LatLng?> _currentLocation() async {
    final position = await currentPosition();
    return position == null
        ? null
        : LatLng(position.latitude, position.longitude);
  }

  /// The button: recentre on the last fix, or ask again (and say why when refused).
  Future<void> _myLocation() async {
    if (_locating) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      // Always ask for a fresh fix; fall back to the last one only if the device cannot provide it.
      final fresh = await _currentLocation();
      if (!mounted) return;
      final here = fresh ?? _here;
      if (here == null) {
        messenger.showSnackBar(SnackBar(content: Text(l.locationDenied)));
        return;
      }
      if (fresh != null) {
        setState(() => _here = fresh);
        unawaited(_draw());
        unawaited(_loadNearby());
        _syncLocationUpdates();
      }
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(here, 15));
      _cameraIdle();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Camera idle: refresh the compass/tilt after a gesture. The camera is queried once here instead of
  /// streaming every move to Dart (`trackCameraPosition: false`), which keeps gestures smooth.
  void _cameraIdle() => unawaited(_onCameraIdle());

  Future<void> _onCameraIdle() async {
    final map = _map;
    if (map == null || !_styled) return;
    CameraPosition? camera;
    try {
      camera = await map.queryCameraPosition();
    } catch (_) {
      return;
    }
    if (!mounted || camera == null) return;
    _setBearing(camera.bearing);
    _setTilt(camera.tilt);
  }

  void _setBearing(double bearing) {
    if (!mounted || (bearing - _bearing).abs() < 0.5) return;
    setState(() => _bearing = bearing);
  }

  void _setTilt(double tilt) {
    if (!mounted || (tilt - _tilt).abs() < 1) return;
    setState(() => _tilt = tilt);
  }

  Future<void> _northUp() async {
    final map = _map;
    if (map == null) return;
    await map.animateCamera(CameraUpdate.bearingTo(0));
    if (mounted) setState(() => _bearing = 0);
  }

  /// Tilts the map between flat (2D) and 45 degrees (3D).
  Future<void> _toggleTilt() async {
    final map = _map;
    if (map == null) return;
    final threeD = _tilt > 1;
    await map.animateCamera(CameraUpdate.tiltTo(threeD ? 0 : 45));
    if (mounted) setState(() => _tilt = threeD ? 0 : 45);
  }

  /// Five kilometres around the phone's fix. Panning or zooming never changes this list.
  static const _nearbyKm = 5.0;

  Future<void> _loadNearby() async {
    final here = _here;
    if (here == null || !mounted) return;
    // One request at a time; a move during the request queues exactly one more.
    if (_nearbyLoading) {
      _nearbyAgain = true;
      return;
    }
    _nearbyLoading = true;
    final generation = ++_generation;
    try {
      // The search point is the phone, not the camera.
      final rows = await _places.nearby(
        here.latitude,
        here.longitude,
        _nearbyKm,
      );
      final measured = sortByDistanceFrom(rows, here.latitude, here.longitude);
      if (!mounted || generation != _generation) return;
      setState(() {
        _nearby = measured;
        _nearbyOrigin = here;
        if (_selectedNearbyId != null &&
            !measured.any((p) => p.branchId == _selectedNearbyId)) {
          _selectedNearbyId = null;
        }
      });
      await _draw();
    } catch (_) {
      // Keep the last result: a failed nearby lookup must not empty the map.
    } finally {
      _nearbyLoading = false;
      if (_nearbyAgain) {
        _nearbyAgain = false;
        if (mounted) unawaited(_loadNearby());
      }
    }
  }

  /// Moves the two "you are here" circles without clearing/rebuilding every annotation.
  Future<void> _moveHereDot(LatLng here) async {
    final map = _map;
    final halo = _hereHalo;
    final dot = _hereDot;
    if (!mounted || map == null || !_styled || halo == null || dot == null) {
      if (mounted) unawaited(_draw());
      return;
    }
    try {
      await map.updateCircle(halo, CircleOptions(geometry: here));
      await map.updateCircle(dot, CircleOptions(geometry: here));
    } catch (_) {
      if (mounted) unawaited(_draw());
    }
  }

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Redraws every pin (a handful per user: no diffing needed). Nearby branches are smaller and muted, under the
  /// saved ones. A hand-set pin has a kunyit ring: not checked yet.
  /// A circle as the legend shows it (MapMark): colours with no alpha, the alpha as opacity.
  CircleOptions _circle(LatLng at, MapMark mark, Notebook nb) {
    final fill = mark.fill(nb);
    return CircleOptions(
      geometry: at,
      circleRadius: mark.radius,
      circleColor: _hex(fill.withValues(alpha: 1)),
      circleOpacity: fill.a,
      circleStrokeWidth: mark.strokeWidth,
      circleStrokeColor: _hex(mark.stroke(nb)),
    );
  }

  Future<void> _draw({bool fit = false}) async {
    final map = _map;
    if (map == null || !_styled || !mounted) return;
    final nb = Notebook.of(context);
    final places = _places.pinned;
    await map.clearCircles();
    _hereHalo = null;
    _hereDot = null;
    final nearby = [
      for (final n in _nearby)
        if (!n.saved && _showCommunity && _all.isEmpty) n,
    ];
    final mineIds = {
      for (final p in places)
        for (final b in p.pins) b.id,
    };
    final all = [
      if (_showCommunity)
        for (final a in _all)
          if (!mineIds.contains(a.branchId)) a,
    ];
    if (all.isNotEmpty) {
      await map.addCircles(
        [
          for (final a in all)
            _circle(LatLng(a.lat, a.lng), MapMark.forSource(a.pinSource), nb),
        ],
        [
          for (final a in all) {'ownerBranch': a.branchId},
        ],
      );
    }
    if (nearby.isNotEmpty) {
      await map.addCircles(
        [
          for (final n in nearby)
            _circle(LatLng(n.lat, n.lng), MapMark.otherMap, nb),
        ],
        [
          for (final n in nearby) {'nearbyBranch': n.branchId},
        ],
      );
    }
    final pins = [
      for (final p in places)
        for (final b in p.pins) (p, b),
    ];
    await map.addCircles(
      [
        for (final (p, b) in pins)
          _circle(
            LatLng(b.lat!, b.lng!),
            !p.mine
                ? MapMark.family
                : b.pinnedByUser
                ? MapMark.mineHandPin
                : MapMark.mine,
            nb,
          ),
      ],
      [
        for (final (p, b) in pins) {'place': p.id, 'branch': b.id},
      ],
    );
    final here = _here;
    if (here != null) {
      final hereCircles = await map.addCircles(
        [
          CircleOptions(
            geometry: here,
            circleRadius: 14,
            circleColor: _hereColor,
            circleOpacity: 0.16,
            circleStrokeWidth: 0,
          ),
          CircleOptions(
            geometry: here,
            circleRadius: 6.5,
            circleColor: _hereColor,
            circleStrokeWidth: 2.5,
            circleStrokeColor: '#FFFFFF',
          ),
        ],
        const [
          {'here': true},
          {'here': true},
        ],
      );
      _hereHalo = hereCircles[0];
      _hereDot = hereCircles[1];
    }
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
    if (!mounted) return;
    final ownerBranch = c.data?['ownerBranch'] as String?;
    if (ownerBranch != null) {
      final nearby = _nearby
          .where((n) => n.branchId == ownerBranch)
          .firstOrNull;
      final all = _all.where((a) => a.branchId == ownerBranch).firstOrNull;
      if (nearby != null) {
        _focusNearby(nearby);
      } else if (all != null) {
        showNotebookSheet<void>(
          context,
          builder: (_) => _OwnerPlaceSheet(place: all, onChanged: _loadAll),
        );
      }
      return;
    }
    final nearbyBranch = c.data?['nearbyBranch'] as String?;
    if (nearbyBranch != null) {
      final nearby = _nearby
          .where((n) => n.branchId == nearbyBranch)
          .firstOrNull;
      // A nearby circle selects its card and centres the map; tapping the card opens the sheet.
      if (nearby != null) _focusNearby(nearby);
      return;
    }
    final place = _places.byId(c.data?['place'] as String? ?? '');
    if (place == null) return;
    final branch =
        place.branches.where((b) => b.id == c.data?['branch']).firstOrNull ??
        place.savedBranch;
    final nearby = _nearby.where((n) => n.branchId == branch?.id).firstOrNull;
    if (nearby != null) {
      setState(() => _selectedNearbyId = nearby.branchId);
    }
    showNotebookSheet<void>(
      context,
      builder: (context) => _PinSheet(place: place, branch: branch),
    );
  }

  /// Search your places and others: fly to the pick. Yours (or an already saved one) opens its sheet, as a tap on
  /// its pin does; another place opens a sheet to save it.
  Future<void> _search() async {
    final l = AppLocalizations.of(context);
    final centre =
        _map?.cameraPosition?.target ?? const LatLng(3.139, 101.6869); // KL
    final hit = await showSearch(
      context: context,
      delegate: MapSearch(
        _places.pinned,
        (q, {required submit}) => _places.search(
          q,
          centre.latitude,
          centre.longitude,
          submit: submit,
        ),
        l,
      ),
    );
    if (hit == null || !mounted) return;
    if (hit is PlaceHit) {
      _flyTo(hit.lat, hit.lng);
      final saved = [
        for (final p in _places.pinned)
          for (final b in p.pins)
            if (b.id == hit.branchId) (p, b),
      ].firstOrNull;
      if (saved != null) {
        showNotebookSheet<void>(
          context,
          builder: (context) => _PinSheet(place: saved.$1, branch: saved.$2),
        );
        return;
      }
      final place = await showNotebookSheet<Place>(
        context,
        builder: (_) => _HitSheet(hit: hit, places: _places),
      );
      if (place != null && mounted) {
        showNotebookSheet<void>(
          context,
          builder: (context) =>
              _PinSheet(place: place, branch: place.savedBranch),
        );
      }
      return;
    }
    final (place, branch) = hit as (Place, Branch);
    _flyTo(branch.lat!, branch.lng!);
    showNotebookSheet<void>(
      context,
      builder: (context) => _PinSheet(place: place, branch: branch),
    );
  }

  void _flyTo(double lat, double lng) {
    unawaited(
      _map?.easeCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
            bearing: _bearing,
            tilt: _tilt,
          ),
        ),
        duration: const Duration(milliseconds: 900),
        interpolation: CameraAnimationInterpolation.easeInOut,
      ),
    );
  }

  /// Carousel snap / map tap: select the card and centre the map on that branch, keeping the 2D/3D angle.
  void _focusNearby(NearbyBranch place) {
    setState(() => _selectedNearbyId = place.branchId);
    final map = _map;
    if (map == null) return;
    unawaited(
      map.easeCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(place.lat, place.lng),
            zoom: 15,
            bearing: _bearing,
            tilt: _tilt,
          ),
        ),
        duration: const Duration(milliseconds: 900),
        interpolation: CameraAnimationInterpolation.easeInOut,
      ),
    );
  }

  void _openNearby(NearbyBranch place) {
    if (place.saved && place.placeId != null) {
      context.push('/places/${place.placeId}');
      return;
    }
    final places = context.read<PlacesController>();
    showNotebookSheet<void>(
      context,
      builder: (context) => NearbySheet(
        place: place,
        onEdited: _loadNearby,
        onSave: () async {
          final saved = await places.saveBranch(place.branchId);
          if (!mounted) return;
          // The saved place carries the branch's fresh rating: canRate is true now for a verified saver.
          final rating = saved.branches
              .where((b) => b.id == place.branchId)
              .firstOrNull
              ?.rating;
          setState(() {
            _nearby = [
              for (final n in _nearby)
                n.branchId == place.branchId
                    ? n.copyWith(saved: true, placeId: saved.id, rating: rating)
                    : n,
            ];
          });
          await _draw();
        },
      ),
    );
  }

  void _showUnpinned() {
    final l = AppLocalizations.of(context);
    showNotebookSheet<void>(
      context,
      // Rebuilds as places get pinned: a found place leaves this list.
      builder: (context) => Consumer<PlacesController>(
        builder: (context, places, _) {
          final text = Theme.of(context).textTheme;
          return ListView(
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
                        if (b.label != null && b.label != p.restaurant.name)
                          Text(b.label!, style: text.bodySmall),
                        UnpinnedActions(place: p, branch: b),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final places = context.watch<PlacesController>();
    final unpinned = places.unpinned.length;
    final shownNearby = _shownNearby;
    final showNearby = shownNearby.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.navMap),
        actions: [
          IconButton(
            tooltip: l.mapSearchHint,
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
          IconButton(
            tooltip: l.creditsTitle,
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/credits'),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: mapStyle,
            initialCameraPosition: malaysiaCamera,
            onMapCreated: _created,
            onStyleLoadedCallback: _styleLoaded,
            onCameraIdle: _cameraIdle,
            // Pan, pinch-zoom, two-finger rotate and two-finger tilt (3D) all on.
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            dragEnabled: true,
            doubleClickZoomEnabled: true,
            compassEnabled: false, // our own north button: always there, on the notebook's paper
            // No per-frame camera stream: the page queries the camera on idle (compass + tilt).
            trackCameraPosition: false,
            // The native location component is created before permission is granted and does not
            // reliably start afterwards; _draw paints our own dot as soon as we have a fix.
            myLocationEnabled: false,
            // Only circles are used; the other annotation managers cost frame time for nothing.
            annotationOrder: const [AnnotationType.circle],
            annotationConsumeTapEvents: const [AnnotationType.circle],
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
              child: Column(
                children: [
                  NorthButton(
                    bearing: _bearing,
                    tooltip: l.northUp,
                    onPressed: _northUp,
                  ),
                  const SizedBox(height: 8),
                  LocationButton(
                    tooltip: l.myLocation,
                    onPressed: _myLocation,
                    busy: _locating,
                  ),
                  const SizedBox(height: 8),
                  ViewModeButton(
                    threeD: _tilt > 1,
                    tooltip: _tilt > 1 ? l.view2d : l.view3d,
                    onPressed: _toggleTilt,
                  ),
                  const SizedBox(height: 8),
                  MapLegendButton(
                    owner: _owner,
                    showCommunity: _showCommunity,
                    onShowCommunity: (on) {
                      setState(() => _showCommunity = on);
                      unawaited(_draw());
                    },
                  ),
                ],
              ),
            ),
          if (places.loaded &&
              places.pinned.isEmpty &&
              _nearby.isEmpty &&
              _here == null)
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
              // The nearby cards have the bottom; the unpinned slip sits just above them.
              bottom: showNearby ? NearbyCarousel.height + 32 : 16,
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
          if (showNearby)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: NearbyCarousel(
                  places: shownNearby,
                  selectedBranchId: _selectedNearbyId,
                  onTap: _openNearby,
                  onSelected: _focusNearby,
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

/// A pin tapped on the map: the place on a notebook sheet, then open it or get directions.
/// A search result not in your book: name, where, and Save (a place new to the app becomes a restaurant). Pops the
/// saved Place.
class _HitSheet extends StatefulWidget {
  const _HitSheet({required this.hit, required this.places});

  final PlaceHit hit;
  final PlacesController places;

  @override
  State<_HitSheet> createState() => _HitSheetState();
}

class _HitSheetState extends State<_HitSheet> {
  bool _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final h = widget.hit;
    setState(() => _saving = true);
    try {
      final place = await (h.branchId != null
          ? widget.places.saveBranch(h.branchId!)
          : widget.places.savePoi(h.poiId!));
      navigator.pop(place);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final h = widget.hit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h.name, style: text.titleLarge),
          Text(
            [distanceText(h.distanceM), ?h.address].join(' · '),
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
          if (h.poiId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.mapSearchNewPlace,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('search-hit-save'),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(l.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _PinSheet extends StatelessWidget {
  const _PinSheet({required this.place, this.branch});

  final Place place;
  final Branch? branch;

  Future<void> _edit(BuildContext context, Branch b) async {
    final owner = context.read<AuthController>().user?.isOwner ?? false;
    final navigator = Navigator.of(context);
    final saved = await showNotebookSheet<bool>(
      context,
      builder: (_) => BranchEditSheet(
        placeId: place.id,
        branch: b,
        canEditShared: owner,
        onSuggest: owner
            ? () => context.read<PlacesController>().suggestBranch(b.id)
            : null,
        onSave: (edit, scope) => context.read<PlacesController>().updateBranch(
          b.id,
          label: edit.label,
          address: edit.address,
          city: edit.city,
          state: edit.state,
          lat: edit.lat,
          lng: edit.lng,
          scope: scope,
        ),
      ),
    );
    if (saved == true && context.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final b = branch;
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  place.restaurant.name,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              if (place.shareId case final id?) SharePhoto(id, size: 64),
            ],
          ),
        ),
        if (b != null)
          NotebookRow(
            mark: PinMark(pinned: b.hasPin),
            trailing: IconButton(
              tooltip: l.editBranch,
              icon: Icon(Icons.edit_outlined, color: nb.inkSoft),
              onPressed: () => _edit(context, b),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.label ?? b.where ?? '-',
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (b.where != null && b.where != b.label)
                  Text(
                    b.where!,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                if (b.pinnedByUser)
                  Text(
                    l.pinnedByUser,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                if (b.pinnedByOwner)
                  Text(
                    l.pinnedByOwner,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                Consumer<PlacesController>(
                  builder: (context, places, _) {
                    final live =
                        places
                            .byId(place.id)
                            ?.branches
                            .where((x) => x.id == b.id)
                            .firstOrNull ??
                        b;
                    return RatingLine(
                      rating: live.rating,
                      onTap: () => context.push('/branches/${b.id}/reviews'),
                    );
                  },
                ),
              ],
            ),
          ),
        if (place.note case final note? when note.isNotEmpty)
          NotebookRow(
            child: Text(
              note,
              style: nb.hand.copyWith(fontSize: 22, color: nb.ink),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/places/${place.id}');
                  },
                  child: Text(l.openPlace),
                ),
              ),
              if (b?.mapsUrl case final url?) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () =>
                        openLink(context, url, failed: l.openFailed),
                    icon: const Icon(Icons.directions),
                    label: Text(l.directions),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The owner's look at any restaurant on the map (one they did not save): where its pin came from, how many saved
/// it, and the shared edits: edit (with the AI draft), check the restaurant's branches, delete the branch.
class _OwnerPlaceSheet extends StatefulWidget {
  const _OwnerPlaceSheet({required this.place, required this.onChanged});

  final OwnerPlace place;

  /// The shared data changed: the map reloads the owner's layer.
  final VoidCallback onChanged;

  @override
  State<_OwnerPlaceSheet> createState() => _OwnerPlaceSheetState();
}

class _OwnerPlaceSheetState extends State<_OwnerPlaceSheet> {
  bool _busy = false;

  OwnerPlace get place => widget.place;

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit() async {
    final places = context.read<PlacesController>();
    final navigator = Navigator.of(context);
    final b = place.branch;
    final saved = await showNotebookSheet<bool>(
      context,
      builder: (_) => BranchEditSheet(
        placeId: '',
        branch: b,
        canEditShared: true,
        onSuggest: () => places.suggestBranch(b.id),
        onSave: (edit, scope) => places.updateBranch(
          b.id,
          label: edit.label,
          address: edit.address,
          city: edit.city,
          state: edit.state,
          lat: edit.lat,
          lng: edit.lng,
          scope: scope,
        ),
      ),
    );
    if (saved == true) {
      widget.onChanged();
      navigator.pop();
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final done = await action();
      if (done == null) return;
      widget.onChanged();
      _snack(done);
      navigator.pop();
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _check() async {
    final l = AppLocalizations.of(context);
    final done = await context.read<PlacesController>().tidyBranches(
      place.restaurantId,
    );
    return l.branchesChecked(done.merged, done.removed);
  }

  Future<String?> _delete() async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    final sure = await showNotebookDialog(
      context,
      message: l.deleteBranchConfirm(
        place.label ?? place.address ?? place.name,
      ),
      tone: DialogTone.danger,
      confirmLabel: l.delete,
    );
    if (!sure) return null;
    await places.deleteBranch(place.branchId);
    return l.deleteBranch;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final where = [
      for (final line in [place.address, place.city, place.state])
        if (line != null && line.isNotEmpty) line,
    ].join(', ');
    return ListView(
      shrinkWrap: true,
      children: [
        NotebookRow(
          mark: MapMarkDot(MapMark.forSource(place.pinSource)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (place.label != null && place.label != place.name)
                Text(
                  place.label!,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              if (where.isNotEmpty)
                Text(
                  where,
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
            ],
          ),
        ),
        NotebookRow(
          mark: Icon(Icons.bookmark_border, size: 20, color: nb.inkSoft),
          child: Text(l.ownerPlaceSavers(place.savers)),
        ),
        NotebookRow(
          mark: Icon(Icons.place_outlined, size: 20, color: nb.inkSoft),
          child: Text(l.ownerPlacePinSource(place.pinSource ?? '-')),
        ),
        NotebookHeading(l.ownerTools),
        NotebookRow(
          mark: Icon(Icons.edit_outlined, size: 20, color: nb.pandanDeep),
          onTap: _busy ? null : _edit,
          child: Text(l.editBranch),
        ),
        NotebookRow(
          mark: Icon(Icons.merge_type, size: 20, color: nb.pandanDeep),
          onTap: _busy ? null : () => _run(_check),
          child: Text(l.checkBranches),
        ),
        NotebookRow(
          mark: Icon(Icons.delete_outline, size: 20, color: nb.margin),
          onTap: _busy ? null : () => _run(_delete),
          child: Text(l.deleteBranch, style: TextStyle(color: nb.margin)),
        ),
      ],
    );
  }
}
