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

/// Camera commands the surrounding chrome needs to issue.
///
/// The screen owns one of these and hands it to [ExploreMap]. Nothing about
/// what the map *shows* travels through it — that is all props — so this stays
/// to the two things a button genuinely has to do imperatively: move the
/// camera, and read where it is.
class ExploreMapController {
  _ExploreMapState? _state;

  bool get isReady => _state?._styleReady ?? false;

  /// Centre on [target], keeping the current bearing and the pitch that the
  /// active view mode implies.
  Future<void> centerOn(LatLng target, {double? zoom}) async =>
      _state?.centerOn(target, zoom: zoom);

  /// Go to [target] and settle close enough to read the street, the way a maps
  /// app's locate button does. Never zooms *out* — see [_ExploreMapState.goToMe].
  Future<void> goToMe(LatLng target) async => _state?.goToMe(target);

  /// Step the zoom by [delta], for the on-screen +/− buttons.
  Future<void> zoomBy(double delta) async => _state?.zoomBy(delta);

  void _attach(_ExploreMapState state) => _state = state;
  void _detach(_ExploreMapState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// The Explore map surface: vector tiles, 3D buildings, people, clusters, you.
///
/// Everything positional is rendered by MapLibre — there is no Flutter widget
/// anywhere over the map except the chrome the screen stacks on top. That is
/// the difference between markers that are welded to the ground through a
/// rotate-and-tilt and markers that swim a frame behind it.
///
/// ## What is animated, and where
///
/// A marker is a bitmap ([ExploreMarkerImages]), so it cannot animate its own
/// contents. Instead three interpolations run on *layers*, which is a fixed
/// cost no matter how many people are on screen:
///
///   * **entrance** — one 480 ms ramp over the whole people layer, driving
///     `icon-size` 0.78→1 and `icon-opacity` 0→1 when a new result lands.
///   * **selection** — the same ramp on a second layer holding only the
///     selected person, overshooting to 1.12 so the pick reads as a lift.
///   * **you** — a slow repeating pulse on the ring around the current user.
///
/// Each tick is one platform call, throttled well below frame rate. The
/// alternative — an `AnimationController` per person — is the thing this
/// design exists to avoid.
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

  /// Where to open before the device fix arrives, so the first paint is a city
  /// rather than the Atlantic.
  final LatLng? initialTarget;

  final ValueChanged<MapUser> onPersonTapped;
  final VoidCallback onBackgroundTapped;

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap>
    with TickerProviderStateMixin {
  // Sources and layers. Named rather than inlined because a typo between the
  // layer that is created and the layer that is later filtered or animated
  // fails silently — the map just quietly stops responding.
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

  /// Generic marker shown the instant a person arrives, before their photo has
  /// been fetched and rasterised. Without it the map would be empty for as long
  /// as the slowest thumbnail takes.
  static const _fallbackIcon = 'radius-person-fallback';

  MapLibreMapController? _map;
  bool _styleReady = false;

  /// Whether the camera has already been moved to the device fix. See
  /// [_centerOnFirstFix].
  bool _centeredOnFirstFix = false;

  final _images = ExploreMarkerImages();

  /// userId → the image id currently registered for them. Starts at the
  /// fallback for everyone and is upgraded as rasters land.
  final Map<String, String> _iconFor = {};

  /// Positions actually drawn, after co-located people have been nudged apart.
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

  // Animation ticks are platform calls, so they are sampled rather than run at
  // frame rate. 22 fps is past the point where these particular interpolations
  // read as smooth, and it is a third of the traffic 60 fps would produce.
  static const _tickInterval = Duration(milliseconds: 45);
  static const _pulseInterval = Duration(milliseconds: 90);
  DateTime _lastEntranceTick = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPulseTick = DateTime.fromMillisecondsSinceEpoch(0);

  /// Coalesces the source rewrites that marker rasters trigger. A hundred
  /// photos landing over a few seconds should cost a handful of updates, not a
  /// hundred.
  Timer? _iconFlush;

  /// Above this zoom the clusterer stops rolling people up and every marker
  /// is an individual. Shared by the source that does the clustering and the
  /// tap fallback that must not fire while it is happening.
  static const double _clusterMaxZoom = 14;

  /// Guards every async continuation that touches the platform: the tab can be
  /// switched away mid-flight, and talking to a disposed map throws.
  bool get _live => mounted && _styleReady && _map != null;

  /// The screen's pixel ratio, which the people layer's `icon-size` has to
  /// cancel out on native — see [ExploreMarkerImages.iconSizeFor].
  ///
  /// Read from the view rather than baked in, because it belongs to the
  /// display the map happens to be on: a desktop window dragged between a
  /// Retina screen and a plain one changes it mid-session, and markers sized
  /// for the old one would be left half or double size.
  double _devicePixelRatio = 1;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _entrance.addListener(_onEntranceTick);
    _selection.addListener(_onEntranceTick);
    _pulse.addListener(_onPulseTick);
    // Ticks are throttled, so the last one before completion can be dropped —
    // which would leave the layer parked at 96% opacity forever. The status
    // change is the one push that must always land.
    _entrance.addStatusListener(_onAnimationStatus);
    _selection.addStatusListener(_onAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio == _devicePixelRatio) return;
    _devicePixelRatio = ratio;
    // Anything already on screen was sized against the old ratio. Safe before
    // the map exists — the push is a no-op until the style is ready.
    unawaited(_pushPersonProperties());
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _iconFlush?.cancel();
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

    // Two different questions, and conflating them is what makes a map replay
    // its entrance animation every time somebody's online dot flickers. A
    // different *set of people* is a new result and deserves the animation; the
    // same people with a changed dot is a redraw and must not.
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

  /// Same people, in the same order. Answers "is this a new result?"
  static bool _sameCast(List<MapUser> a, List<MapUser> b) => listEquals(
        [for (final user in a) user.id],
        [for (final user in b) user.id],
      );

  /// Same people *and* the same markers. Answers "does anything need redrawing?"
  ///
  /// The screen rebuilds on every presence tick, and a tick that changed
  /// nobody's dot must not cost a hundred re-rasterised faces. Only what a
  /// marker is actually made of counts: who, where, online, and which photo.
  static bool _sameCrowd(List<MapUser> a, List<MapUser> b) => listEquals(
        [for (final user in a) _markerIdentity(user)],
        [for (final user in b) _markerIdentity(user)],
      );

  static String _markerIdentity(MapUser user) =>
      '${user.id}|${user.isOnline}|${user.primaryPhotoUrl}'
      // The distance is drawn beside the face, so a person who moved closer is
      // a redraw even though their generalized pin snapped to the same grid.
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
        // The full set: pan, pinch, rotate, tilt. Explore is a place to look
        // around in, so nothing is taken away.
        rotateGesturesEnabled: true,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        tiltGesturesEnabled: true,
        trackCameraPosition: true,
        // Chrome the app draws for itself, at the sizes and in the corners the
        // rest of the screen expects.
        compassEnabled: false,
        myLocationEnabled: false,
        logoEnabled: false,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        // Every layer is created with interaction off, so the native hit test
        // never claims a tap and this fires for all of them — one code path
        // for people, clusters and empty map alike.
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

  /// Move to the device fix the first time there is one.
  ///
  /// [MapLibreMap.initialCameraPosition] is read exactly once, when the
  /// platform view is created — and the fix usually arrives a second or two
  /// after that. Without this the map opens over the country-scale fallback
  /// and simply stays there, with the user's own marker somewhere off screen.
  ///
  /// Once only. After the first fix the camera belongs to whoever is panning
  /// it, and a later GPS update yanking the view back would be the map
  /// fighting the person using it.
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
        // Slightly wider than a marker, so two markers never sit close enough
        // to overlap without merging.
        clusterRadius: 58,
        // Past this, everyone is drawn individually. It is deliberately below
        // the zoom where buildings extrude: arriving in the 3D city should
        // mean arriving at people, not at a number.
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

    // Clusters, bottom to top: halo, disc, count.
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
        // Blue through violet as a group grows — the app's own gradient, in
        // steps rather than a ramp so a cluster's size band is readable.
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
        // Upright through every rotation and tilt. Without these the count
        // lies flat on the ground and turns upside down when the map spins.
        textRotationAlignment: 'viewport',
        textPitchAlignment: 'viewport',
      ),
      filter: isCluster,
      enableInteraction: false,
    );

    // People. Two layers over one source: the selected person is excluded from
    // the base layer and drawn by the second, so selection can be animated
    // without scaling everybody.
    // The spot on the ground each person's marker stands on.
    //
    // Two jobs. It reads as the marker's contact point, which is what stops a
    // tilted map from looking like faces hovering over a city. And it is drawn
    // from geometry rather than from a registered image, so if a face ever
    // fails to rasterise or register, the person is still visible and still
    // tappable rather than silently absent from a map that claims to show them.
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

    // Created at full visibility, then animated in — not the other way round.
    //
    // Creating these at `progress: 0` meant a layer whose baseline state was
    // invisible, and whose only route to being seen was a stream of
    // `setLayerProperties` calls. Any platform where those quietly do nothing
    // (maplibre_gl_web applies paint properties but not layout ones) leaves
    // the map permanently empty while the header cheerfully reports the count.
    // Visible is the safe default; the entrance animation is an enhancement on
    // top of it, and its final frame lands on this same value anyway.
    await map.addSymbolLayer(
      _peopleSource,
      _peopleLayer,
      _personProperties(progress: 1, selected: false),
      filter: notCluster,
      enableInteraction: false,
    );
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

    // How far away each face is, printed beside it.
    //
    // Above the marker layers so a label is never buried under the person
    // standing behind them, and on its own layer rather than as the people
    // layer's `textField`: that layer is rewritten on every animation tick, and
    // scaling a distance with the entrance would leave the number stretching.
    await map.addSymbolLayer(
      _peopleSource,
      _peopleDistanceLayer,
      _distanceProperties(),
      filter: notCluster,
      enableInteraction: false,
    );

    // You. Not a dating profile — a pulse, a dot, and a word.
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

  /// Cluster disc radius by member count, scaled by [factor] so the halo layer
  /// can reuse the same size bands.
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
  //
  // `setLayerProperties` sends the map WITHOUT skipping nulls, so anything left
  // out of one of these is reset to its default. They must therefore each be
  // the complete set for their layer, and the creation call and the animation
  // ticks must both go through the same builder — otherwise the first tick
  // silently strips whatever creation set and animation didn't.

  SymbolLayerProperties _personProperties({
    required double progress,
    required bool selected,
  }) {
    final eased = Curves.easeOutBack.transform(progress.clamp(0, 1));
    final base = selected ? 1.12 : 1.0;
    // Grows into place rather than popping: 0.78 → full size.
    final scale = (0.78 + 0.22 * eased) * base;

    return SymbolLayerProperties(
      iconImage: ['get', 'icon'],
      // Life size, which is not the same number on every platform — the
      // plugin declares these bitmaps at a different pixel ratio on native
      // than on the web. See ExploreMarkerImages.iconSizeFor.
      iconSize: ExploreMarkerImages.iconSizeFor(_devicePixelRatio) * scale,
      // The marker's tail tip sits on the coordinate.
      iconAnchor: 'bottom',
      // People are the point of the map: they overlap each other and they
      // overlap labels, rather than being dropped by the label engine.
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      // Upright under rotation and pitch, always.
      iconRotationAlignment: 'viewport',
      iconPitchAlignment: 'viewport',
      iconOpacity: Curves.easeOut.transform(progress.clamp(0, 1)),
      // Lower sort key means drawn on top. With the map north-up — which it
      // is unless somebody has deliberately rotated it — southern markers are
      // the near ones, so latitude straight through puts the near marker over
      // the far one instead of behind it.
      symbolSortKey: ['get', 'sort'],
    );
  }

  /// "450 m", set beside a person's face.
  ///
  /// ## Where the offsets come from
  ///
  /// The marker bitmap is anchored `bottom`, so its tail tip is on the
  /// coordinate and everything else is above it. At life size that puts the
  /// centre of the photo disc `disc/2 + glow + tail` ≈ 43 px up, and its right
  /// edge `disc/2` ≈ 27 px across. `text-offset` is in ems of [_distanceSize],
  /// so those two distances become the constants below — the label lands level
  /// with the face and just clear of the ring, at every zoom, because both the
  /// marker and the text are sized in screen space rather than on the ground.
  static const double _distanceSize = 11.5;

  SymbolLayerProperties _distanceProperties({double progress = 1}) {
    return SymbolLayerProperties(
      textField: ['get', 'distance'],
      textFont: const ['Noto Sans Bold'],
      textSize: _distanceSize,
      // Left edge of the text at the offset point, so a long value grows away
      // from the face rather than back across it.
      textAnchor: 'left',
      textOffset: const [2.9, -3.75],
      textColor: AppMapColors.plum.toHexStringRGB(),
      // The map under a marker is pastel road and building fill, not a flat
      // ground colour, so the halo is what keeps the number legible.
      textHaloColor: AppColors.onImage.toHexStringRGB(),
      textHaloWidth: 1.9,
      textHaloBlur: 0.3,
      textOpacity: Curves.easeOut.transform(progress.clamp(0, 1)),
      // Same as the faces: people are the point of the map, so their labels
      // are not candidates for the label engine to drop.
      textAllowOverlap: true,
      textIgnorePlacement: true,
      // Upright through every rotation and tilt.
      textRotationAlignment: 'viewport',
      textPitchAlignment: 'viewport',
      symbolSortKey: ['get', 'sort'],
    );
  }

  CircleLayerProperties _mePulseProperties(double progress) {
    // One outward sweep per cycle: the ring grows and fades, then restarts.
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
    // Always push the final frame, or the layer is left mid-animation.
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
      await map.setLayerProperties(
        _selectedLayer,
        _personProperties(
          // Its own controller, and *only* its own: taking the max with the
          // entrance meant that once the entrance had finished at 1, every
          // later selection was already at full size and the lift never
          // played. The layer is empty until somebody is picked anyway, so it
          // has nothing to animate in alongside the crowd.
          progress: _selection.value,
          selected: true,
        ),
      );
      // Fades in with the crowd it labels. Only the entrance drives it — a
      // selection empties this layer rather than scaling it.
      await map.setLayerProperties(
        _peopleDistanceLayer,
        _distanceProperties(progress: _entrance.value),
      );
    } catch (_) {
      // The style can be torn down between the tick and the call landing.
      // Dropping a frame of an animation is not worth surfacing.
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

    // Everyone starts on the generic marker so the map fills immediately;
    // their own face replaces it as it rasterises.
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
      // A new set of people is either the first load or the result of somebody
      // changing the radius or the filters. Both are moments where the honest
      // thing to do is show them what they just asked for.
      await _frameOnPeople();
    }

    unawaited(_loadMarkerImages());
  }

  Future<void> _writePeopleSource() async {
    if (!_live) return;
    try {
      await _map!.setGeoJsonSource(_peopleSource, _peopleGeoJson());
    } catch (_) {
      // Style swapped out from under us; the next publish will redo it.
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
                  // Printed beside the face by _peopleDistanceLayer. Empty
                  // rather than absent when the server sent no number: a
                  // missing property makes `['get', 'distance']` null, and
                  // maplibre-gl-js logs an expression error for every feature
                  // it evaluates that on.
                  'distance': formatDistance(user.distanceMeters) ?? '',
                  // Higher for people further north, so painting order runs
                  // back-to-front on a tilted map.
                  'sort': at.latitude,
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [at.longitude, at.latitude],
                },
              },
        ],
      };

  /// Rasterises faces and registers them, a few at a time.
  ///
  /// Bounded concurrency because the alternative is a hundred simultaneous
  /// image fetches and decodes, which on a mid-range phone stalls the very
  /// frame the map is trying to draw. Source rewrites are coalesced by
  /// [_scheduleIconFlush] so a batch costs one update, not one per face.
  Future<void> _loadMarkerImages() async {
    final queue = List<MapUser>.from(widget.users);
    const workers = 4;

    Future<void> worker() async {
      while (queue.isNotEmpty && _live) {
        final user = queue.removeAt(0);
        final selected = user.id == widget.selectedId;
        try {
          await _register(user, selected: false);
          // The selected face is a second raster at a second size; only ever
          // one of them exists at a time.
          if (selected) await _register(user, selected: true);
        } catch (_) {
          // Keep the fallback marker. One unreachable photo is not a reason to
          // stop drawing the other ninety-nine people.
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

    // Is the bigger, brighter raster for this person on the GPU yet?
    //
    // On a first selection it never is — it is built on demand — and what the
    // map does in that gap is the whole of this method's difficulty. It used to
    // hide the crowd *and* draw nobody in their place, so tapping somebody
    // blanked the map until the raster landed, and blanked it permanently if
    // the raster failed. The person you just picked is the one thing that must
    // stay on screen.
    final selectedImage = selected == null
        ? null
        : ExploreMarkerImages.imageId(selected, selected: true);
    final ready = selectedImage != null && _images.has(selectedImage);

    // Picking somebody empties the map of everyone else.
    //
    // The alternative — highlight them and leave the crowd up — makes "who am I
    // looking at" a question the user has to keep answering, and on a dense map
    // the person they just chose is the one hardest to keep track of. Clearing
    // the map is also what makes the bottom composer unambiguous: there is
    // exactly one person on screen, and the message goes to them.
    final focused = selected != null;
    final filters = peopleLayerFilters(selectedId: selectedId, ready: ready);

    try {
      await _map!.setFilter(_peopleLayer, filters.base);
      await _map!.setFilter(_peopleGroundLayer, filters.ground);
      await _map!.setFilter(_selectedLayer, filters.selected);
      await _map!.setFilter(_peopleDistanceLayer, filters.distance);
      for (final layer in const [
        _clusterGlowLayer,
        _clusterLayer,
        _clusterCountLayer,
      ]) {
        await _map!.setFilter(layer, filters.clusters);
      }
    } catch (_) {
      return;
    }

    // Go to them. Selection arrives from three places — a marker, the strip and
    // the grid — and all three should land the camera in the same place, so the
    // move lives here rather than at each call site.
    if (focused) {
      final at = _drawn[selected.id];
      if (at != null) unawaited(centerOn(at, zoom: ExploreCamera.focusZoom));
    }

    if (selected != null && !ready) {
      // Build the bigger raster, then come back through here to swap it in.
      //
      // Failure is survivable now and must stay that way: the plain marker is
      // already on screen from the filters above, so a photo that will not
      // decode costs the highlight, not the person. Swallowing here is also
      // what stops an unhandled async error reaching the console.
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

    // A rect rather than the bare point: the incoming coordinate and the query
    // share the platform's pixel space, and a few pixels of slop is the
    // difference between "tapped her" and "tapped the road behind her".
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
          // Included so a person stays reachable even in the case the ground
          // dot exists to cover: a face that never rasterised.
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
      final person =
          widget.users.where((user) => user.id == id).firstOrNull;
      if (person != null) {
        // The camera move belongs to _applySelection, which every route into a
        // selection passes through — doing it here too would animate twice.
        widget.onPersonTapped(person);
        return;
      }
    }

    // Nothing rendered answered. Fall back to geometry.
    //
    // `queryRenderedFeatures` is the precise tool and also the fragile one: it
    // needs every layer id in the request to exist, and maplibre-gl-js answers
    // a request naming an unknown layer with an error on the console and an
    // empty list. That failure is indistinguishable from "you tapped the road",
    // so a single mis-created layer silently costs the whole tap interaction.
    // The markers' coordinates are already in Dart, so the tap can be resolved
    // against them directly and identically on every platform.
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

  /// Step into a cluster rather than jumping past it, so the group visibly
  /// breaks apart into the people in it.
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

    // `cameraPosition`, not `queryCameraPosition()`. The latter throws
    // UnimplementedError on web — it is one of a handful of methods
    // maplibre_gl_web never implemented — which took the centre-on-me button
    // down with it. This getter is kept up to date by the camera-move stream
    // (`trackCameraPosition: true` on the widget), so it needs no platform
    // call at all and behaves the same on every platform.
    final current = map.cameraPosition;

    try {
      await map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom ?? current?.zoom ?? ExploreCamera.defaultZoom,
            tilt: ExploreCamera.pitchFor(widget.viewMode),
            // Whatever way they turned the map is theirs to keep — snapping
            // back to north because they pressed "centre on me" would undo a
            // deliberate act.
            bearing: current?.bearing ?? 0,
          ),
        ),
        duration: ExploreCamera.transition,
      );
    } catch (_) {}
  }

  /// The locate button's move: centre on the user *and* arrive somewhere they
  /// can see where they are.
  ///
  /// [centerOn] deliberately keeps the current zoom, which is right when the
  /// camera is already somewhere deliberate. It was wrong here. Pressing
  /// "where am I" from a city-wide view re-centred the map and left it city
  /// wide, so the answer to "where am I" was a purple dot in a field of
  /// rooftops — the button appeared to do nothing, because the only thing that
  /// moved was scenery.
  ///
  /// So it zooms to street level, and takes the *larger* of that and where the
  /// camera already is: somebody who had zoomed into their own building and
  /// then panned away is asking to go back, not to be pulled back out.
  Future<void> goToMe(LatLng target) async {
    final map = _map;
    if (map == null || !_styleReady) return;

    // A later GPS fix must not drag the camera off the spot they just asked
    // for — see _centerOnFirstFix.
    _centeredOnFirstFix = true;

    final current = map.cameraPosition?.zoom ?? ExploreCamera.defaultZoom;
    await centerOn(
      target,
      zoom: math.max(current, ExploreCamera.meZoom),
    );
  }

  /// Open the camera around everyone the map is showing, not at a fixed zoom.
  ///
  /// This is what was wrong with the first version. It always opened at
  /// [ExploreCamera.defaultZoom], which on a phone-width viewport covers about
  /// ±3.4 km — while the radius filter goes up to "10 km+". So with a wide
  /// radius the map was correct, the header counted the right people, and every
  /// one of them was rendered off screen. The map looked empty and there was
  /// nothing on it to suggest scrolling.
  ///
  /// Framing on the actual result set fixes that for every radius at once, and
  /// keeps working if the bands are ever changed.
  ///
  /// Deliberately **not** `CameraUpdate.newLatLngBounds`: that helper resets
  /// tilt and bearing to zero, which would flatten the 3D view every time the
  /// radius changed. Computing the zoom here keeps the camera the user chose.
  Future<void> _frameOnPeople() async {
    if (!_live) return;

    final points = [
      ..._drawn.values,
      // Include ourselves: "who is around me" is a question about a place, and
      // a frame that excludes the viewer does not answer it.
      ?widget.myLocation,
    ];
    if (points.isEmpty) return;

    final viewport = context.size;
    if (viewport == null || viewport.isEmpty) return;

    // Framing supersedes centring on the device fix. Without this, a GPS fix
    // that lands after the people do would yank the camera back to the user at
    // a fixed zoom and throw the frame away.
    _centeredOnFirstFix = true;

    final frame = frameFor(
      points,
      viewport: viewport,
      minZoom: ExploreCamera.minZoom,
      // Never closer than the zoom a tap on a person settles at, so a tight
      // group does not arrive already inside a building.
      maxZoom: ExploreCamera.focusZoom,
      soloZoom: ExploreCamera.defaultZoom,
      tilted: widget.viewMode == ExploreViewMode.tilted,
    );
    if (frame == null) return;

    await centerOn(frame.centre, zoom: frame.zoom);
  }

  /// One step of the on-screen zoom buttons, clamped to the map's own range so
  /// the control goes inert at the ends rather than pretending to work.
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

  /// The 2D/3D toggle. Tilt only — the position and zoom people chose stay put.
  Future<void> _applyPitch() async {
    if (!_live) return;
    try {
      await _map!.animateCamera(
        CameraUpdate.tiltTo(ExploreCamera.pitchFor(widget.viewMode)),
        duration: ExploreCamera.transition,
      );
    } catch (_) {}
  }

  /// A hex string between two colours, for the cluster step ramp.
  static String _blend(Color a, Color b, double t) =>
      Color.lerp(a, b, t)!.toHexStringRGB();
}
