import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_format.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/explore_provider.dart';
import '../marker_layout.dart';
import 'explore_marker_images.dart';

/// Lets the surrounding screen move the camera (zoom buttons, locate button).
/// What the map shows is passed in as props, not through this controller.
class ExploreMapController {
  _ExploreMapState? _state;

  bool get isReady => _state?._styleReady ?? false;

  /// Centres on [target], keeping bearing and the pitch of the current view mode.
  Future<void> centerOn(LatLng target, {double? zoom}) async =>
      _state?.centerOn(target, zoom: zoom);

  /// Centres on [target] at street level. Never zooms out.
  Future<void> goToMe(LatLng target) async => _state?.goToMe(target);

  /// Changes the zoom by [delta] (used by the +/- buttons).
  Future<void> zoomBy(double delta) async => _state?.zoomBy(delta);

  void _attach(_ExploreMapState state) => _state = state;

  void _detach(_ExploreMapState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// The Explore map: vector tiles, 3D buildings, people, clusters and "you".
///
/// Everything positional is drawn by MapLibre layers, so markers stay attached
/// to the ground while the map rotates and tilts. Animations run on whole
/// layers (people entrance, selection lift, "you" pulse) instead of one
/// controller per person, so the cost does not grow with the crowd.
class ExploreMap extends StatefulWidget {
  const ExploreMap({
    super.key,
    required this.styleString,
    required this.controller,
    required this.users,
    required this.viewMode,
    required this.onPersonTapped,
    required this.onBackgroundTapped,
    this.myLocation,
    this.selectedId,
    this.initialTarget,
  });

  final String styleString;
  final ExploreMapController controller;
  final List<MapUser> users;
  final ExploreViewMode viewMode;
  final LatLng? myLocation;
  final String? selectedId;

  /// Where to open before the device location arrives.
  final LatLng? initialTarget;

  final ValueChanged<MapUser> onPersonTapped;
  final VoidCallback onBackgroundTapped;

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap>
    with TickerProviderStateMixin {
  // Source and layer ids. Kept as constants because a typo between creating a
  // layer and later filtering it fails silently.
  static const _peopleSource = 'radius-people';
  static const _meSource = 'radius-me';
  static const _clusterGlowLayer = 'radius-cluster-glow';
  static const _clusterLayer = 'radius-cluster';
  static const _clusterCountLayer = 'radius-cluster-count';
  static const _peopleGroundLayer = 'radius-people-ground';
  static const _peopleLayer = 'radius-people';
  static const _selectedLayer = 'radius-people-selected';
  static const _peopleDistanceLayer = 'radius-people-distance';
  static const _mePulseLayer = 'radius-me-pulse';
  static const _meCoreLayer = 'radius-me-core';
  static const _meLabelLayer = 'radius-me-label';

  /// Generic marker shown until a person's photo has been loaded.
  static const _fallbackIcon = 'radius-person-fallback';

  /// Above this zoom, clusters break apart into individual people.
  static const double _clusterMaxZoom = 14;

  /// Animation updates are platform calls, so they are throttled.
  static const _tickInterval = Duration(milliseconds: 45);
  static const _pulseInterval = Duration(milliseconds: 90);

  MapLibreMapController? _map;
  bool _styleReady = false;

  /// True once the camera has moved to the device location for the first time.
  bool _centeredOnFirstFix = false;

  final _images = ExploreMarkerImages();

  /// User id -> image id currently used for that person's marker.
  final Map<String, String> _iconFor = {};

  /// Marker positions actually drawn, after co-located people are spread out.
  Map<String, LatLng> _drawn = {};

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _selection = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  DateTime _lastEntranceTick = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPulseTick = DateTime.fromMillisecondsSinceEpoch(0);

  /// Batches source rewrites while many marker photos load.
  Timer? _iconFlush;

  /// Whether it is safe to talk to the native map. Every async step checks
  /// this, because the map can be disposed while a call is in flight.
  bool get _live => mounted && _styleReady && _map != null;

  double _devicePixelRatio = 1;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _entrance.addListener(_onEntranceTick);
    _selection.addListener(_onEntranceTick);
    _pulse.addListener(_onPulseTick);
    // Throttling can drop the last tick, so the final frame is pushed on
    // completion instead.
    _entrance.addStatusListener(_onAnimationStatus);
    _selection.addStatusListener(_onAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio == _devicePixelRatio) return;
    _devicePixelRatio = ratio;
    unawaited(_pushPersonProperties());
  }

  @override
  void dispose() {
    // Mark the map as gone first so any call still in flight stops touching
    // the native view. This is part of the crash fix.
    _styleReady = false;
    _map = null;
    _iconFlush?.cancel();
    widget.controller._detach(this);
    _entrance.dispose();
    _selection.dispose();
    _pulse.dispose();
    _images.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExploreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (!_live) return;

    // A different set of people replays the entrance animation; the same
    // people with a changed online dot only redraws.
    if (!_sameCast(oldWidget.users, widget.users)) {
      unawaited(_publishPeople(animateIn: true));
    } else if (!_sameCrowd(oldWidget.users, widget.users)) {
      unawaited(_publishPeople());
    }
    if (oldWidget.selectedId != widget.selectedId) {
      unawaited(_applySelection());
    }
    if (oldWidget.viewMode != widget.viewMode) {
      unawaited(_applyPitch());
    }
    if (oldWidget.myLocation != widget.myLocation) {
      unawaited(_publishMe());
      unawaited(_centerOnFirstFix());
    }
  }

  /// Same people in the same order.
  static bool _sameCast(List<MapUser> a, List<MapUser> b) => listEquals(
    [for (final user in a) user.id],
    [for (final user in b) user.id],
  );

  /// Same people and the same marker contents (position, online dot, photo,
  /// distance).
  static bool _sameCrowd(List<MapUser> a, List<MapUser> b) => listEquals(
    [for (final user in a) _markerIdentity(user)],
    [for (final user in b) _markerIdentity(user)],
  );

  static String _markerIdentity(MapUser user) =>
      '${user.id}|${user.isOnline}|${user.primaryPhotoUrl}'
          '|${user.latitude}|${user.longitude}|${user.distanceMeters}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Explore map. People near you, shown where they roughly are. '
          'Pinch to zoom, drag with two fingers to tilt and rotate.',
      child: MapLibreMap(
        styleString: widget.styleString,
        initialCameraPosition: CameraPosition(
          target: widget.myLocation ??
              widget.initialTarget ??
              const LatLng(20.5937, 78.9629),
          zoom: widget.myLocation == null
              ? ExploreCamera.defaultZoom - 3
              : ExploreCamera.defaultZoom,
          tilt: ExploreCamera.pitchFor(widget.viewMode),
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(
          ExploreCamera.minZoom,
          ExploreCamera.maxZoom,
        ),
        rotateGesturesEnabled: true,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        tiltGesturesEnabled: true,
        trackCameraPosition: true,
        compassEnabled: false,
        myLocationEnabled: false,
        logoEnabled: false,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        // All layers are created with interaction off, so every tap arrives
        // through onMapClick.
        featureTapsTriggersMapClick: true,
        onMapCreated: (controller) => _map = controller,
        onStyleLoadedCallback: _onStyleLoaded,
        onMapClick: (point, coordinates) =>
            unawaited(_onTap(point, coordinates)),
      ),
    );
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || !mounted) return;

    await _images.registerFallback(map, _fallbackIcon);
    if (!mounted) return;

    await _createSources(map);
    if (!mounted) return;

    await _createLayers(map);
    if (!mounted) return;

    _styleReady = true;
    _pulse.repeat();

    await _publishMe();
    await _centerOnFirstFix();
    await _publishPeople(animateIn: true);
    await _applySelection();
  }

  /// Moves the camera to the device location the first time it is known.
  /// The initial camera position is only read once, and the location usually
  /// arrives after that. Later updates never move the camera again.
  Future<void> _centerOnFirstFix() async {
    if (_centeredOnFirstFix || !_live) return;
    final me = widget.myLocation;
    if (me == null) return;

    _centeredOnFirstFix = true;
    await centerOn(me, zoom: ExploreCamera.defaultZoom);
  }

  Future<void> _createSources(MapLibreMapController map) async {
    await map.addSource(
      _peopleSource,
      const GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterRadius: 58,
        clusterMaxZoom: _clusterMaxZoom,
      ),
    );
    await map.addSource(
      _meSource,
      const GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
      ),
    );
  }

  Future<void> _createLayers(MapLibreMapController map) async {
    const isCluster = ['has', 'point_count'];
    const notCluster = [
      '!',
      ['has', 'point_count'],
    ];

    // Clusters: halo, disc, count.
    await map.addCircleLayer(
      _peopleSource,
      _clusterGlowLayer,
      CircleLayerProperties(
        circleRadius: _clusterRadius(1.55),
        circleColor: AppMapColors.plum.toHexStringRGB(),
        circleOpacity: 0.16,
        circleBlur: 0.85,
        circlePitchAlignment: 'map',
      ),
      filter: isCluster,
      enableInteraction: false,
    );
    await map.addCircleLayer(
      _peopleSource,
      _clusterLayer,
      CircleLayerProperties(
        circleRadius: _clusterRadius(1),
        circleColor: [
          'step',
          ['get', 'point_count'],
          AppColors.primary.toHexStringRGB(),
          11,
          _blend(AppColors.primary, AppMapColors.plum, 0.4),
          51,
          AppMapColors.plum.toHexStringRGB(),
          201,
          AppMapColors.you.toHexStringRGB(),
        ],
        circleStrokeWidth: 3,
        circleStrokeColor: AppColors.onImage.toHexStringRGB(),
        circleStrokeOpacity: 0.92,
        circlePitchAlignment: 'map',
      ),
      filter: isCluster,
      enableInteraction: false,
    );
    await map.addSymbolLayer(
      _peopleSource,
      _clusterCountLayer,
      SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textFont: const ['Noto Sans Bold'],
        textSize: [
          'step',
          ['get', 'point_count'],
          13.0,
          11,
          15.0,
          51,
          17.0,
          201,
          19.0,
        ],
        textColor: AppColors.onImage.toHexStringRGB(),
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textRotationAlignment: 'viewport',
        textPitchAlignment: 'viewport',
      ),
      filter: isCluster,
      enableInteraction: false,
    );

    // A dot on the ground under each marker. It is drawn from geometry rather
    // than an image, so a person is still visible and tappable even if their
    // photo fails to load.
    await map.addCircleLayer(
      _peopleSource,
      _peopleGroundLayer,
      CircleLayerProperties(
        circleRadius: ['interpolate', ['linear'], ['zoom'], 11, 2.5, 17, 5.0],
        circleColor: AppMapColors.plum.toHexStringRGB(),
        circleOpacity: 0.3,
        circleBlur: 0.4,
        circlePitchAlignment: 'map',
      ),
      filter: notCluster,
      enableInteraction: false,
    );

    // People are created fully visible and then animated, so a platform that
    // ignores property updates still shows them.
    await map.addSymbolLayer(
      _peopleSource,
      _peopleLayer,
      _personProperties(progress: 1, selected: false),
      filter: notCluster,
      enableInteraction: false,
    );
    // The selected person is drawn on their own layer so selection can animate
    // without scaling everyone.
    await map.addSymbolLayer(
      _peopleSource,
      _selectedLayer,
      _personProperties(progress: 1, selected: true),
      filter: const [
        'all',
        notCluster,
        ['==', ['get', 'id'], '__none__'],
      ],
      enableInteraction: false,
    );

    // Distance label beside each face, on its own layer so it does not stretch
    // with the marker animation.
    await map.addSymbolLayer(
      _peopleSource,
      _peopleDistanceLayer,
      _distanceProperties(),
      filter: notCluster,
      enableInteraction: false,
    );

    // The current user: pulse, dot and label.
    await map.addCircleLayer(
      _meSource,
      _mePulseLayer,
      _mePulseProperties(0),
      enableInteraction: false,
    );
    await map.addCircleLayer(
      _meSource,
      _meCoreLayer,
      CircleLayerProperties(
        circleRadius: 8.5,
        circleColor: AppMapColors.you.toHexStringRGB(),
        circleStrokeWidth: 3.5,
        circleStrokeColor: AppColors.onImage.toHexStringRGB(),
        circlePitchAlignment: 'viewport',
      ),
      enableInteraction: false,
    );
    await map.addSymbolLayer(
      _meSource,
      _meLabelLayer,
      SymbolLayerProperties(
        textField: 'YOU',
        textFont: const ['Noto Sans Bold'],
        textSize: 10.5,
        textLetterSpacing: 0.14,
        textOffset: const [0, 2.1],
        textColor: AppMapColors.you.toHexStringRGB(),
        textHaloColor: AppColors.onImage.toHexStringRGB(),
        textHaloWidth: 1.6,
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textRotationAlignment: 'viewport',
        textPitchAlignment: 'viewport',
      ),
      enableInteraction: false,
    );
  }

  /// Cluster disc radius by member count. [factor] lets the halo reuse the
  /// same size bands.
  List<Object> _clusterRadius(double factor) => [
    'step',
    ['get', 'point_count'],
    17.0 * factor,
    11,
    23.0 * factor,
    51,
    29.0 * factor,
    201,
    35.0 * factor,
  ];

  // ── Layer property sets ───────────────────────────────────────────────────
  // setLayerProperties resets anything left out, so each builder returns the
  // complete set for its layer and is used for both creation and animation.

  SymbolLayerProperties _personProperties({
    required double progress,
    required bool selected,
  }) {
    final eased = Curves.easeOutBack.transform(progress.clamp(0, 1));
    final base = selected ? 1.12 : 1.0;
    final scale = (0.78 + 0.22 * eased) * base;

    return SymbolLayerProperties(
      iconImage: ['get', 'icon'],
      iconSize: ExploreMarkerImages.iconSizeFor(_devicePixelRatio) * scale,
      // The marker's tail tip sits on the coordinate.
      iconAnchor: 'bottom',
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      iconRotationAlignment: 'viewport',
      iconPitchAlignment: 'viewport',
      iconOpacity: Curves.easeOut.transform(progress.clamp(0, 1)),
      // Lower key draws on top; using latitude puts nearer (southern) markers
      // over farther ones on a north-up map.
      symbolSortKey: ['get', 'sort'],
    );
  }

  /// Distance text (for example "450 m") beside a person's face. The offsets
  /// place it level with the photo and just clear of its ring.
  static const double _distanceSize = 11.5;

  SymbolLayerProperties _distanceProperties({double progress = 1}) {
    return SymbolLayerProperties(
      textField: ['get', 'distance'],
      textFont: const ['Noto Sans Bold'],
      textSize: _distanceSize,
      textAnchor: 'left',
      textOffset: const [2.9, -3.75],
      textColor: AppMapColors.plum.toHexStringRGB(),
      textHaloColor: AppColors.onImage.toHexStringRGB(),
      textHaloWidth: 1.9,
      textHaloBlur: 0.3,
      textOpacity: Curves.easeOut.transform(progress.clamp(0, 1)),
      textAllowOverlap: true,
      textIgnorePlacement: true,
      textRotationAlignment: 'viewport',
      textPitchAlignment: 'viewport',
      symbolSortKey: ['get', 'sort'],
    );
  }

  CircleLayerProperties _mePulseProperties(double progress) {
    // One ring that grows and fades, then restarts.
    final eased = Curves.easeOut.transform(progress.clamp(0, 1));
    return CircleLayerProperties(
      circleRadius: 12 + 30 * eased,
      circleColor: AppMapColors.youPulse.toHexStringRGB(),
      circleOpacity: 0.30 * (1 - eased),
      circleStrokeWidth: 1.5,
      circleStrokeColor: AppMapColors.youPulse.toHexStringRGB(),
      circleStrokeOpacity: 0.45 * (1 - eased),
      circlePitchAlignment: 'viewport',
    );
  }

  // ── Animation ticks ───────────────────────────────────────────────────────

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) unawaited(_pushPersonProperties());
  }

  void _onEntranceTick() {
    final now = DateTime.now();
    final settled = !_entrance.isAnimating && !_selection.isAnimating;
    // The final frame is always pushed so the layer is never left mid-animation.
    if (!settled && now.difference(_lastEntranceTick) < _tickInterval) return;
    _lastEntranceTick = now;
    unawaited(_pushPersonProperties());
  }

  Future<void> _pushPersonProperties() async {
    if (!_live) return;
    final map = _map!;
    try {
      await map.setLayerProperties(
        _peopleLayer,
        _personProperties(progress: _entrance.value, selected: false),
      );
      // The selected layer uses only the selection animation, so the lift
      // plays on every selection.
      await map.setLayerProperties(
        _selectedLayer,
        _personProperties(progress: _selection.value, selected: true),
      );
      await map.setLayerProperties(
        _peopleDistanceLayer,
        _distanceProperties(progress: _entrance.value),
      );
    } catch (_) {
      // The map can be torn down between the tick and the call. Dropping one
      // animation frame is harmless.
    }
  }

  void _onPulseTick() {
    final now = DateTime.now();
    if (now.difference(_lastPulseTick) < _pulseInterval) return;
    _lastPulseTick = now;
    if (!_live || widget.myLocation == null) return;
    unawaited(
      _map!
          .setLayerProperties(_mePulseLayer, _mePulseProperties(_pulse.value))
          .catchError((_) {}),
    );
  }

  // ── Publishing data ───────────────────────────────────────────────────────

  Future<void> _publishPeople({bool animateIn = false}) async {
    if (!_live) return;

    _drawn = spreadColocated(widget.users);

    // Everyone starts on the fallback marker; real photos replace it as they load.
    for (final user in widget.users) {
      _iconFor.putIfAbsent(user.id, () => _fallbackIcon);
    }
    _iconFor.removeWhere(
          (id, _) => !widget.users.any((user) => user.id == id),
    );

    await _writePeopleSource();
    if (!_live) return;

    if (animateIn) {
      _entrance
        ..reset()
        ..forward();
      await _frameOnPeople();
    }

    unawaited(_loadMarkerImages());
  }

  Future<void> _writePeopleSource() async {
    if (!_live) return;
    try {
      await _map!.setGeoJsonSource(_peopleSource, _peopleGeoJson());
    } catch (_) {
      // Style was replaced or the map is gone; the next publish redoes it.
    }
  }

  Map<String, dynamic> _peopleGeoJson() => {
    'type': 'FeatureCollection',
    'features': [
      for (final user in widget.users)
        if (_drawn[user.id] case final at?)
          {
            'type': 'Feature',
            'properties': {
              'id': user.id,
              'icon': _iconFor[user.id] ?? _fallbackIcon,
              // Empty string rather than null when the distance is unknown.
              'distance': formatDistance(user.distanceMeters) ?? '',
              // Latitude as sort key so drawing runs back to front.
              'sort': at.latitude,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [at.longitude, at.latitude],
            },
          },
    ],
  };

  /// Loads marker photos with a small number of workers, so a large crowd does
  /// not stall the frame with a hundred simultaneous decodes.
  Future<void> _loadMarkerImages() async {
    final queue = List<MapUser>.from(widget.users);
    const workers = 4;

    Future<void> worker() async {
      while (queue.isNotEmpty && _live) {
        final user = queue.removeAt(0);
        final selected = user.id == widget.selectedId;
        try {
          await _register(user, selected: false);
          if (selected) await _register(user, selected: true);
        } catch (_) {
          // Keep the fallback marker for anyone whose photo fails.
        }
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  Future<void> _register(MapUser user, {required bool selected}) async {
    final id = ExploreMarkerImages.imageId(user, selected: selected);
    if (!_images.has(id)) {
      final bytes = await _images.build(user, selected: selected);
      if (!_live) return;
      await _map!.addImage(id, bytes);
    }
    if (!_live) return;

    if (!selected && _iconFor[user.id] != id) {
      _iconFor[user.id] = id;
      _scheduleIconFlush();
    }
    if (selected) await _applySelection();
  }

  void _scheduleIconFlush() {
    _iconFlush?.cancel();
    _iconFlush = Timer(
      const Duration(milliseconds: 140),
          () => unawaited(_writePeopleSource()),
    );
  }

  Future<void> _publishMe() async {
    if (!_live) return;
    final me = widget.myLocation;
    try {
      await _map!.setGeoJsonSource(_meSource, {
        'type': 'FeatureCollection',
        'features': [
          if (me != null)
            {
              'type': 'Feature',
              'properties': const <String, dynamic>{},
              'geometry': {
                'type': 'Point',
                'coordinates': [me.longitude, me.latitude],
              },
            },
        ],
      });
    } catch (_) {}
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  Future<void> _applySelection() async {
    if (!_live) return;
    final selectedId = widget.selectedId;
    final selected = selectedId == null
        ? null
        : widget.users.where((user) => user.id == selectedId).firstOrNull;

    // The larger selected-marker image is built on demand, so it may not be
    // ready yet. The plain marker stays visible until it is.
    final selectedImage = selected == null
        ? null
        : ExploreMarkerImages.imageId(selected, selected: true);
    final ready = selectedImage != null && _images.has(selectedImage);

    // Selecting someone hides everyone else, so the composer below clearly
    // targets the one person on screen.
    final focused = selected != null;
    final filters = peopleLayerFilters(selectedId: selectedId, ready: ready);

    try {
      final map = _map!;
      await map.setFilter(_peopleLayer, filters.base);
      await map.setFilter(_peopleGroundLayer, filters.ground);
      await map.setFilter(_selectedLayer, filters.selected);
      await map.setFilter(_peopleDistanceLayer, filters.distance);
      for (final layer in const [
        _clusterGlowLayer,
        _clusterLayer,
        _clusterCountLayer,
      ]) {
        await map.setFilter(layer, filters.clusters);
      }
    } catch (_) {
      return;
    }

    // Every route into a selection (marker, strip, grid) ends here, so the
    // camera move lives here too.
    if (focused) {
      final at = _drawn[selected.id];
      if (at != null) unawaited(centerOn(at, zoom: ExploreCamera.focusZoom));
    }

    if (selected != null && !ready) {
      // Build the larger image, then come back to swap it in. A failure only
      // costs the highlight, not the person.
      unawaited(
        _register(selected, selected: true).catchError((Object _) {}),
      );
      return;
    }

    if (ready) {
      _selection
        ..reset()
        ..forward();
    } else {
      _selection.value = 0;
      unawaited(_pushPersonProperties());
    }
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  Future<void> _onTap(math.Point<double> point, LatLng coordinates) async {
    if (!_live) return;

    // Query a small rectangle rather than a single point so near-misses count.
    final rect = Rect.fromCenter(
      center: Offset(point.x, point.y),
      width: 44,
      height: 44,
    );

    List<dynamic> hits;
    try {
      hits = await _map!.queryRenderedFeaturesInRect(
        rect,
        [
          _selectedLayer,
          _peopleLayer,
          _peopleGroundLayer,
          _clusterLayer,
          _clusterCountLayer,
        ],
        null,
      );
    } catch (_) {
      return;
    }
    if (!_live) return;

    for (final hit in hits) {
      if (hit is! Map) continue;
      final properties = hit['properties'];
      if (properties is! Map) continue;

      final count = (properties['point_count'] as num?)?.toInt();
      if (count != null) {
        await _zoomIntoCluster(hit);
        return;
      }

      final id = properties['id'] as String?;
      final person = widget.users.where((user) => user.id == id).firstOrNull;
      if (person != null) {
        widget.onPersonTapped(person);
        return;
      }
    }

    // Nothing rendered was hit, so fall back to matching the tap against the
    // known marker coordinates. This works even if a layer query fails.
    final person = personNearTap(
      tap: coordinates,
      people: widget.users,
      drawn: _drawn,
      zoom: _map?.cameraPosition?.zoom ?? ExploreCamera.defaultZoom,
      clusterMaxZoom: _clusterMaxZoom,
      focused: widget.selectedId != null,
    );
    if (person != null) {
      widget.onPersonTapped(person);
      return;
    }

    widget.onBackgroundTapped();
  }

  /// Zooms in on a cluster so it visibly breaks apart.
  Future<void> _zoomIntoCluster(Map<dynamic, dynamic> feature) async {
    final geometry = feature['geometry'];
    if (geometry is! Map) return;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return;

    final current = _map?.cameraPosition;
    final target = LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
    final zoom = math.min(
      ExploreCamera.maxZoom,
      (current?.zoom ?? ExploreCamera.defaultZoom) + 2,
    );
    await centerOn(target, zoom: zoom);
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> centerOn(LatLng target, {double? zoom}) async {
    final map = _map;
    if (map == null || !_styleReady) return;

    // Uses the tracked cameraPosition getter, which needs no platform call
    // (queryCameraPosition is not implemented on web).
    final current = map.cameraPosition;

    try {
      await map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom ?? current?.zoom ?? ExploreCamera.defaultZoom,
            tilt: ExploreCamera.pitchFor(widget.viewMode),
            // Keep the rotation the user chose.
            bearing: current?.bearing ?? 0,
          ),
        ),
        duration: ExploreCamera.transition,
      );
    } catch (_) {}
  }

  /// Locate button: centres on the user and zooms to street level, but never
  /// zooms out from where the camera already is.
  Future<void> goToMe(LatLng target) async {
    final map = _map;
    if (map == null || !_styleReady) return;

    // A later location update must not pull the camera away from here.
    _centeredOnFirstFix = true;

    final current = map.cameraPosition?.zoom ?? ExploreCamera.defaultZoom;
    await centerOn(
      target,
      zoom: math.max(current, ExploreCamera.meZoom),
    );
  }

  /// Frames the camera around everyone shown (and the user), instead of a
  /// fixed zoom that could leave people off screen.
  ///
  /// Not CameraUpdate.newLatLngBounds, because that resets tilt and bearing.
  Future<void> _frameOnPeople() async {
    if (!_live) return;

    final points = [
      ..._drawn.values,
      ?widget.myLocation,
    ];
    if (points.isEmpty) return;

    final viewport = context.size;
    if (viewport == null || viewport.isEmpty) return;

    // Framing replaces the first-location centring.
    _centeredOnFirstFix = true;

    final frame = frameFor(
      points,
      viewport: viewport,
      minZoom: ExploreCamera.minZoom,
      maxZoom: ExploreCamera.focusZoom,
      soloZoom: ExploreCamera.defaultZoom,
      tilted: widget.viewMode == ExploreViewMode.tilted,
    );
    if (frame == null) return;

    await centerOn(frame.centre, zoom: frame.zoom);
  }

  /// One step of the on-screen zoom buttons, clamped to the map's zoom range.
  Future<void> zoomBy(double delta) async {
    final map = _map;
    if (map == null || !_styleReady) return;

    final current = map.cameraPosition;
    final next = ((current?.zoom ?? ExploreCamera.defaultZoom) + delta)
        .clamp(ExploreCamera.minZoom, ExploreCamera.maxZoom);
    try {
      await map.animateCamera(
        CameraUpdate.zoomTo(next),
        duration: const Duration(milliseconds: 260),
      );
    } catch (_) {}
  }

  /// 2D/3D toggle. Changes tilt only.
  Future<void> _applyPitch() async {
    if (!_live) return;
    try {
      await _map!.animateCamera(
        CameraUpdate.tiltTo(ExploreCamera.pitchFor(widget.viewMode)),
        duration: ExploreCamera.transition,
      );
    } catch (_) {}
  }

  /// Colour halfway between two colours, as a hex string.
  static String _blend(Color a, Color b, double t) =>
      Color.lerp(a, b, t)!.toHexStringRGB();
}