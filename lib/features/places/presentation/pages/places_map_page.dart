import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../owner/domain/owner.dart';
import '../../../owner/domain/owner_repository.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/nearby_math.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/map_search.dart';
import '../widgets/location_button.dart';
import '../widgets/map_legend.dart';
import '../widgets/map_place_sheets.dart';
import '../widgets/map_sheet.dart';
import '../widgets/nearby_card.dart';
import '../widgets/nearby_sheet.dart';
import '../widgets/north_button.dart';
import '../widgets/unpinned_actions.dart';
import '../widgets/view_mode_button.dart';
import '../location.dart';

/// OpenFreeMap: free vector tiles, no key, no request cap; its styles carry the OpenStreetMap attribution.
/// Liberty in light mode, Dark in dark mode; a switch reloads the style, and [_styleLoaded] redraws our layers.
String mapStyle(BuildContext context) =>
    'https://tiles.openfreemap.org/styles/${Theme.of(context).brightness == Brightness.dark ? 'dark' : 'liberty'}';
const malaysiaCamera = CameraPosition(target: LatLng(4.2, 102.0), zoom: 4.6);
// The "you are here" dot. Drawn by us (not the native location component) so it appears as soon as
// the permission result arrives, even when the map was created before permission was granted.
const _hereColor = '#1E88E5';

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
  const PlacesMapPage({super.key, this.active = true, this.focus});

  /// Open centred on this point (a place's pin, from its page) instead of the user's location or all pins.
  final LatLng? focus;

  /// The Map tab is visible. Location tracking runs only while this and the app are active.
  final bool active;

  @override
  State<PlacesMapPage> createState() => _PlacesMapPageState();
}

class _PlacesMapPageState extends State<PlacesMapPage>
    with WidgetsBindingObserver {
  MapLibreMapController? _map;
  bool _styled = false;

  /// The pins' source and layers (added on every style load), and each feature's tap data by feature id.
  bool _layers = false;
  final _features = <String, Map<String, dynamic>>{};

  /// Face images in the style, by avatar id, and the ones loading (a loaded one redraws).
  final _faceReady = <String>{};
  final _faceLoading = <String>{};
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

  /// What the sheet shows: null = the list (near me); else a NearbyBranch, (Place, Branch?), PlaceHit,
  /// OwnerPlace, [_unpinned] or a map label ([MapLabel]). [_shown] bumps on each pick: the sheet rises for it.
  Object? _selected;
  int _shown = 0;
  final _sheet = DraggableScrollableController();
  static const _unpinned = 'unpinned';

  /// OpenFreeMap Liberty's place labels (the Dark style draws none, so there is nothing to tap there).
  static const _poiLayers = ['poi_r1', 'poi_r7', 'poi_r20'];
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
    _places.changes.addListener(_loadNearby);
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
    _places.changes.removeListener(_loadNearby);
    _sheet.dispose();
    _map?.onCircleTapped.remove(_tapped);
    _map?.onFeatureTapped.remove(_featureTapped);
    // Calls still in flight find no map and stop (see quietMap).
    _map = null;
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
    setState(
      () => _map = c
        ..onCircleTapped.add(_tapped)
        ..onFeatureTapped.add(_featureTapped),
    );
  }

  Future<void> _styleLoaded() async {
    _styled = true;
    // A new style has none of our source, layers or images.
    _layers = false;
    _faceReady.clear();
    _faceLoading.clear();
    if (widget.focus case final focus?) {
      await _draw();
      await quietMap(
        _map?.animateCamera(CameraUpdate.newLatLngZoom(focus, 16)),
      );
      _cameraIdle();
      return;
    }
    await _draw(fit: _here == null);
    if (_here case final here?) {
      await quietMap(_map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14)));
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
      // Opened on a place: the camera stays on it.
      if (widget.focus != null) {
        return;
      }
      await quietMap(_map?.animateCamera(CameraUpdate.newLatLngZoom(here, 14)));
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
      await quietMap(_map?.animateCamera(CameraUpdate.newLatLngZoom(here, 15)));
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
    await quietMap(map.animateCamera(CameraUpdate.bearingTo(0)));
    if (mounted) setState(() => _bearing = 0);
  }

  /// Tilts the map between flat (2D) and 45 degrees (3D).
  Future<void> _toggleTilt() async {
    final map = _map;
    if (map == null) return;
    final threeD = _tilt > 1;
    await quietMap(map.animateCamera(CameraUpdate.tiltTo(threeD ? 0 : 45)));
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

  static const _source = 'pins';
  static const _clusterLayer = 'pins-cluster';
  static const _countLayer = 'pins-count';
  static const _dotLayer = 'pins-dot';
  static const _faceLayer = 'pins-face';

  /// A pin as the legend shows it (MapMark), for the dot layer: colours with no alpha, the alpha as opacity.
  Map<String, dynamic> _mark(MapMark mark, Notebook nb) {
    final fill = mark.fill(nb);
    return {
      'fill': _hex(fill.withValues(alpha: 1)),
      'opacity': fill.a,
      'stroke': _hex(mark.stroke(nb)),
      'r': mark.radius,
      'sw': mark.strokeWidth,
    };
  }

  /// Every pin is one feature of one clustered GeoJSON source; the style animates the rest. Zoomed out, pins
  /// merge into clusters with a count (green when one is in your book); between zoom 9 and 12 a dot grows from a
  /// small dot to full size; a family member's photo fades in over their dot from 10.5 to 11.5, the dot's size.
  Future<void> _addLayers(MapLibreMapController map, Notebook nb) async {
    await map.addSource(
      _source,
      const GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterMaxZoom: 11,
        clusterRadius: 44,
        // How many of a cluster's pins are in your book (yours or family's).
        clusterProperties: {
          'book': [
            '+',
            [
              'case',
              ['get', 'book'],
              1,
              0,
            ],
          ],
        },
      ),
    );
    const clustered = ['has', 'point_count'];
    await map.addCircleLayer(
      _source,
      _clusterLayer,
      CircleLayerProperties(
        circleRadius: const [
          'step',
          ['get', 'point_count'],
          14,
          10,
          17,
          50,
          21,
        ],
        circleColor: [
          'case',
          [
            '>',
            ['get', 'book'],
            0,
          ],
          _hex(nb.pandan),
          '#7B8A80',
        ],
        circleOpacity: 0.92,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
      filter: clustered,
    );
    await map.addSymbolLayer(
      _source,
      _countLayer,
      SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textFont: ['Noto Sans Bold'], // in the OpenFreeMap style's glyphs
        textSize: 12,
        textColor: _hex(nb.paper), // white on light mode's deep green, near-black on dark mode's pale green
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: clustered,
    );
    await map.addCircleLayer(
      _source,
      _dotLayer,
      const CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          [
            '*',
            ['get', 'r'],
            0.45,
          ],
          12,
          ['get', 'r'],
        ],
        circleStrokeWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          [
            'min',
            ['get', 'sw'],
            1.5,
          ],
          12,
          ['get', 'sw'],
        ],
        circleColor: ['get', 'fill'],
        circleOpacity: ['get', 'opacity'],
        circleStrokeColor: ['get', 'stroke'],
        circleSortKey: ['get', 'z'], // your book's pins over the others
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
    await map.addSymbolLayer(
      _source,
      _faceLayer,
      const SymbolLayerProperties(
        iconImage: ['get', 'face'],
        // The image is the full dot's size: it shrinks with the dot.
        iconSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          0.45,
          12,
          1,
        ],
        iconOpacity: [
          'interpolate',
          ['linear'],
          ['zoom'],
          10.5,
          0,
          11.5,
          1,
        ],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        'all',
        [
          '!',
          ['has', 'point_count'],
        ],
        ['has', 'face'],
      ],
    );
  }

  /// Redraws the pins; quiet once the native map has gone (see [quietMap]).
  Future<void> _draw({bool fit = false}) => quietMap(_paint(fit: fit));

  Future<void> _paint({bool fit = false}) async {
    final map = _map;
    if (map == null || !_styled || !mounted) return;
    final nb = Notebook.of(context);
    final places = _places.pinned;
    if (!_layers) {
      _layers = true;
      try {
        await _addLayers(map, nb);
      } catch (_) {
        _layers = false;
        return;
      }
      if (!mounted) return;
    }
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
    final features = <Map<String, dynamic>>[];
    _features.clear();
    void add(
      double lat,
      double lng,
      Map<String, dynamic> props,
      Map<String, dynamic> tap,
    ) {
      final id = 'f${features.length}';
      _features[id] = tap;
      features.add({
        'type': 'Feature',
        'id': id,
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': props,
      });
    }

    for (final a in all) {
      add(
        a.lat,
        a.lng,
        {..._mark(MapMark.forSource(a.pinSource), nb), 'z': 0, 'book': false},
        {'ownerBranch': a.branchId},
      );
    }
    for (final n in nearby) {
      add(
        n.lat,
        n.lng,
        {..._mark(MapMark.otherMap, nb), 'z': 0, 'book': false},
        {'nearbyBranch': n.branchId},
      );
    }
    final ring = MapMark.family.stroke(nb);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (final p in places) {
      // A family member's save shows their photo once it is in the style.
      final saver = p.mine
          ? null
          : p.savedBy
                .where((s) => !s.isMe && s.avatar != null && s.userId != null)
                .firstOrNull;
      if (saver != null) _loadFace(saver.userId!, saver.avatar!, ring, dpr);
      for (final b in p.pins) {
        add(
          b.lat!,
          b.lng!,
          {
            ..._mark(
              !p.mine
                  ? MapMark.family
                  : b.pinnedByUser
                  ? MapMark.mineHandPin
                  : MapMark.mine,
              nb,
            ),
            'z': 1,
            'book': true,
            if (saver != null && _faceReady.contains(saver.avatar))
              'face': 'face-${saver.avatar}',
          },
          {'place': p.id, 'branch': b.id},
        );
      }
    }
    // New data replaces the old in place: no clear-and-redraw flicker.
    await map.setGeoJsonSource(_source, {
      'type': 'FeatureCollection',
      'features': features,
    });
    if (!mounted) return;
    await map.clearCircles();
    _hereHalo = null;
    _hereDot = null;
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
    await quietMap(
      map.animateCamera(
        single
            ? CameraUpdate.newLatLngZoom(box.southwest, 14)
            : CameraUpdate.newLatLngBounds(
                box,
                left: 48,
                top: 64,
                right: 48,
                bottom: 120,
              ),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  /// A face: the photo, round, in the family ring, added to the style once; then the pins are drawn again.
  void _loadFace(String userId, String avatar, Color ring, double dpr) {
    if (_faceReady.contains(avatar) || !_faceLoading.add(avatar)) return;
    final auth = context.read<AuthController>();
    unawaited(() async {
      try {
        final bytes = await auth.avatar(userId, avatar);
        final map = _map;
        if (bytes == null || map == null || !mounted) return;
        await map.addImage('face-$avatar', await _roundFace(bytes, ring, dpr));
        _faceReady.add(avatar);
        if (mounted) unawaited(_draw());
      } catch (_) {
        // No photo: the plain dot stays.
      }
    }());
  }

  /// A cluster zooms in on itself; a pin acts as its circle did.
  Future<void> _featureTapped(
    Point<double> point,
    LatLng at,
    String id,
    String layer,
    Annotation? annotation,
  ) async {
    if (layer == _clusterLayer || layer == _countLayer) {
      final map = _map;
      double zoom = 9;
      try {
        zoom = (await map?.queryCameraPosition())?.zoom ?? 9;
      } on PlatformException {
        return;
      }
      await quietMap(
        map?.animateCamera(
          CameraUpdate.newLatLngZoom(at, zoom + 2),
          duration: const Duration(milliseconds: 500),
        ),
      );
    } else if (layer == _dotLayer || layer == _faceLayer) {
      _onTap(_features[id]);
    }
  }

  void _tapped(Circle c) => _onTap(c.data);

  void _onTap(Map<dynamic, dynamic>? data) {
    if (!mounted) return;
    final ownerBranch = data?['ownerBranch'] as String?;
    if (ownerBranch != null) {
      final nearby = _nearby
          .where((n) => n.branchId == ownerBranch)
          .firstOrNull;
      final all = _all.where((a) => a.branchId == ownerBranch).firstOrNull;
      if (nearby != null) {
        _showNearby(nearby);
      } else if (all != null) {
        _show(all, lat: all.branch.lat, lng: all.branch.lng);
      }
      return;
    }
    final nearbyBranch = data?['nearbyBranch'] as String?;
    if (nearbyBranch != null) {
      final nearby = _nearby
          .where((n) => n.branchId == nearbyBranch)
          .firstOrNull;
      if (nearby != null) _showNearby(nearby);
      return;
    }
    final place = _places.byId(data?['place'] as String? ?? '');
    if (place == null) return;
    final branch =
        place.branches.where((b) => b.id == data?['branch']).firstOrNull ??
        place.savedBranch;
    _show((place, branch), lat: branch?.lat, lng: branch?.lng);
  }

  /// A tap on the map itself: a place label (OSM) shows its name at once, then our place of that name there if
  /// there is one; anywhere else goes back to the list, as Google Maps does.
  Future<void> _mapClicked(Point<double> point, LatLng at) async {
    final map = _map;
    if (map == null) return;
    List<dynamic> features = const [];
    try {
      features = await map.queryRenderedFeatures(point, _poiLayers, null);
    } on PlatformException {
      // A style still loading has no layers to ask.
    }
    final name = [
      for (final f in features)
        if (f case {'properties': {'name': final String n}}) n,
    ].firstOrNull;
    if (!mounted) return;
    if (name == null) {
      if (_selected != null) _show(null);
      return;
    }
    final label = MapLabel(name, at.latitude, at.longitude);
    _show(label, lat: at.latitude, lng: at.longitude);
    try {
      final hits = await _places.search(
        name,
        at.latitude,
        at.longitude,
        submit: false,
      );
      final hit = hits.where((h) => h.distanceM < 250).firstOrNull;
      if (hit == null || !mounted || _selected != label) return;
      setState(() => _selected = _pinOf(hit) ?? hit);
    } catch (_) {
      // The name stays: the label is all we know.
    }
  }

  /// A branch in your book, as a pin tap shows it.
  (Place, Branch)? _pinOf(PlaceHit hit) => [
    for (final p in _places.pinned)
      for (final b in p.pins)
        if (b.id == hit.branchId) (p, b),
  ].firstOrNull;

  /// The sheet shows [what] (null = the list), and the map centres a point above it.
  void _show(Object? what, {double? lat, double? lng}) {
    setState(() {
      _selected = what;
      _shown++;
    });
    final height = MediaQuery.sizeOf(context).height;
    unawaited(
      quietMap(
        _map?.updateContentInsets(
          what == null
              ? EdgeInsets.zero
              : isWide(context)
              ? EdgeInsets.only(left: _panelLeft(context) + sidePanelWidth)
              : EdgeInsets.only(bottom: height * MapSheet.half),
        ),
      ),
    );
    if (lat != null && lng != null) _flyTo(lat, lng);
  }

  /// A nearby place: yours as your pin, another one with Save.
  void _showNearby(NearbyBranch n) {
    final mine = n.saved ? _places.byId(n.savedPlaceId ?? '') : null;
    _show(
      mine == null
          ? n
          : (
              mine,
              mine.branches.where((b) => b.id == n.branchId).firstOrNull ??
                  mine.savedBranch,
            ),
      lat: n.lat,
      lng: n.lng,
    );
  }

  /// The sheet's "done" or X: back to the list; a saved search hit shows as your pin.
  void _closed(Object? result) =>
      result is Place ? _show((result, result.savedBranch)) : _show(null);

  /// Others' places near the map's centre, for the search bar.
  Future<List<PlaceHit>> _searchNear(String q, {required bool submit}) {
    final centre =
        _map?.cameraPosition?.target ?? const LatLng(3.139, 101.6869); // KL
    return _places.search(q, centre.latitude, centre.longitude, submit: submit);
  }

  /// A search pick: fly there. Yours (or an already saved one) opens its sheet, as a tap on its pin does; another
  /// place opens a sheet to save it.
  Future<void> _picked(Object hit) async {
    if (!mounted) return;
    if (hit is PlaceHit) {
      _show(_pinOf(hit) ?? hit, lat: hit.lat, lng: hit.lng);
      return;
    }
    final (place, branch) = hit as (Place, Branch);
    _show((place, branch), lat: branch.lat, lng: branch.lng);
  }

  void _flyTo(double lat, double lng) {
    unawaited(
      quietMap(
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
      ),
    );
  }

  Widget _nearbySheet(NearbyBranch place) => NearbySheet(
    place: place,
    onEdited: _loadNearby,
    onSave: () async {
      final saved = await _places.saveBranch(place.branchId);
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
                ? n.copyWith(
                    saved: true,
                    savedPlaceId: saved.id,
                    rating: rating,
                  )
                : n,
        ];
      });
      await _draw();
    },
  );

  /// Places with no pin, each with Find location / Set on map. Rebuilds as places get pinned: a found one leaves.
  Widget _unpinnedList(AppLocalizations l) => Consumer<PlacesController>(
    builder: (context, places, _) {
      final text = Theme.of(context).textTheme;
      return ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
            child: Text(
              l.unpinnedHelp,
              style: text.bodyMedium?.copyWith(
                color: Notebook.of(context).inkSoft,
              ),
            ),
          ),
          for (final p in places.unpinned)
            ListTile(
              leading: const PinMark(pinned: false),
              onTap: () => context.push('/places/${p.id}'),
              title: Column(
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
  );

  /// The sheet's list: near me (the phone's location), and the places with no pin.
  Widget _nearbyList(AppLocalizations l) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final shown = _shownNearby;
    final unpinned = _places.unpinned.length;
    return ListView(
      key: const ValueKey('map-sheet-list'),
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.feedNearMe,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_nearbyLoading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: spaceS),
        if (_here == null)
          InkWell(
            onTap: _myLocation,
            child: Text(
              l.feedLocationOff,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          )
        else if (shown.isEmpty && !_nearbyLoading)
          Text(
            l.mapSearchNone,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        for (final n in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: spaceS),
            child: SizedBox(
              key: ValueKey('nearby-card-${n.branchId}'),
              height: NearbyCard.heightOf(context),
              child: NearbyCard(place: n, onTap: () => _showNearby(n)),
            ),
          ),
        if (unpinned > 0)
          ListTile(
            key: const ValueKey('map-sheet-unpinned'),
            contentPadding: EdgeInsets.zero,
            leading: const PinMark(pinned: false),
            title: Text(
              l.unpinnedCount(unpinned),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(Icons.chevron_right, color: nb.inkSoft),
            onTap: () => _show(_unpinned),
          ),
      ],
    );
  }

  Widget _sheetContent(AppLocalizations l) => switch (_selected) {
    null => _nearbyList(l),
    _unpinned => _unpinnedList(l),
    final NearbyBranch n => _nearbySheet(n),
    (final Place p, final Branch? b) => PinSheet(place: p, branch: b),
    final PlaceHit h => SearchHitSheet(hit: h, places: _places),
    final OwnerPlace o => OwnerPlaceSheet(place: o, onChanged: _loadAll),
    final MapLabel label => MapLabelSheet(label: label),
    _ => const SizedBox.shrink(),
  };

  /// On a wide screen, where the side panel and the search bar above it start (past a notch on its side).
  double _panelLeft(BuildContext context) =>
      12 + MediaQuery.paddingOf(context).left;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final places = context.watch<PlacesController>();
    final side = isWide(context);
    // No app bar: the search bar floats on the map, the buttons below it. The keyboard covers the map and the
    // sheet (resizing a native map view stutters).
    final belowBar =
        MediaQuery.paddingOf(context).top + 8 + MapSearchBar.height + 12;
    // Lowered, the sheet keeps its handle and the first line of what it shows.
    final peek =
        36 +
        MediaQuery.textScalerOf(context).scale(48) +
        MediaQuery.paddingOf(context).bottom;
    return PopScope(
      // Back closes what the sheet shows first, as Google Maps does.
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _show(null);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          // The keyboard covers the map instead of resizing it: a native map view re-laid out every frame stutters.
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              MapLibreMap(
                styleString: mapStyle(context),
                initialCameraPosition: malaysiaCamera,
                onMapCreated: _created,
                onStyleLoadedCallback: _styleLoaded,
                onCameraIdle: _cameraIdle,
                onMapClick: _mapClicked,
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
                // Pins are style layers (_addLayers); annotations are only the you-are-here dot.
                annotationOrder: const [AnnotationType.circle],
                annotationConsumeTapEvents: const [AnnotationType.circle],
                logoEnabled: false,
                // The credit OpenStreetMap needs stays, as a faint "i" in the bottom-left corner.
                attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                attributionButtonMargins: Point(
                  side ? _panelLeft(context) + sidePanelWidth + 8 : 8,
                  side ? 8 : peek + 8,
                ),
                attributionButtonColor: nb.ink.withValues(alpha: 0.3),
              ),
              if (_map != null)
                Positioned(
                  top: belowBar,
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
                  right: 72,
                  top: belowBar,
                  child: MapSlip(
                    child: Text(l.mapEmpty, textAlign: TextAlign.center),
                  ),
                ),
              // Keyed: the slips above come and go, and a re-created sheet would attach its controller twice.
              Positioned(
                key: const ValueKey('map-sheet-host'),
                top: 0,
                bottom: 0,
                left: side ? _panelLeft(context) : 0,
                width: side ? sidePanelWidth : null,
                right: side ? null : 0,
                child: MapSheet(
                  controller: _sheet,
                  peek: peek,
                  top: belowBar - 12,
                  shown: _shown,
                  showClose: _selected != null,
                  onClose: _closed,
                  child: KeyedSubtree(
                    key: ValueKey(_shown),
                    child: _sheetContent(l),
                  ),
                ),
              ),
              // Last: its results drop over everything else.
              // On a wide screen, over the side panel (its SafeArea takes the notch off the left).
              Positioned(
                top: 0,
                left: 12,
                width: side
                    ? sidePanelWidth + MediaQuery.paddingOf(context).left
                    : null,
                right: side ? null : 12,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MapSearchBar(
                      places: places.pinned,
                      search: _searchNear,
                      recent: _places.recentSearches,
                      onPicked: _picked,
                      reserveBottom: peek,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 22 points across, the family dot's full size (radius 8 + ring 3): [ring] round the photo, cropped to a circle. PNG at the screen's pixel ratio (the map
/// reads an image at that ratio on Android and iOS), so it stays sharp.
Future<Uint8List> _roundFace(Uint8List photo, Color ring, double dpr) async {
  final size = (22 * dpr).round();
  final border = 3 * dpr;
  final codec = await ui.instantiateImageCodec(
    photo,
    targetWidth: size,
    targetHeight: size, // the picture is a square crop already
  );
  final image = (await codec.getNextFrame()).image;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final c = Offset(size / 2, size / 2);
  canvas.drawCircle(c, size / 2, Paint()..color = ring);
  final inner = Rect.fromCircle(center: c, radius: size / 2 - border);
  canvas.clipPath(Path()..addOval(inner));
  paintImage(canvas: canvas, rect: inner, image: image, fit: BoxFit.cover);
  final out = await rec.endRecording().toImage(size, size);
  final png = await out.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

/// A map call that may outlive its map: leaving the map page mid-animation (or the activity being recreated)
/// destroys the native view, and the call then fails with MAP_NOT_READY, or with MissingPluginException once its
/// channel is gone (a redraw still running when the page was left). Nothing is left to update, so it is dropped.
Future<void> quietMap(Future<Object?>? call) async {
  try {
    await call;
  } on PlatformException {
    // The map has gone.
  } on MissingPluginException {
    // Its channel has gone too.
  }
}
