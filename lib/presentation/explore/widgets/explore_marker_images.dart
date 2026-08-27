import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show MapLibreMapController;

import '../../../core/theme/app_colors.dart';
import '../../../data/models/discovery_user_model.dart';
import '../../../data/models/map_user_model.dart';

/// Turns people into the bitmaps MapLibre draws as markers.
///
/// ## Why bitmaps and not widgets
///
/// The obvious build is a `Stack` of Flutter avatars positioned by projecting
/// each person to a screen point. It falls apart the moment the map tilts:
/// every projection is an async platform round-trip, and doing one per person
/// per frame of a pan is a budget the map does not have. Handing MapLibre an
/// image and a coordinate moves all of that onto the GPU alongside the tiles,
/// where a pan costs nothing extra, and the marker stays welded to its patch of
/// ground through rotation and pitch instead of chasing it a frame late.
///
/// The trade is that a marker is a picture, so its *content* cannot animate.
/// That is why appearance and selection are animated on the layer instead (see
/// `ExploreMapLayers`): one interpolation for the whole layer rather than one
/// controller per person.
///
/// ## Cost
///
/// One decode and one 168 px raster per person per state. Photos are fetched
/// through [CachedNetworkImageProvider] with a `maxWidth`, so a marker pulls a
/// thumbnail off disk on the second look and never decodes a full-resolution
/// portrait. Rasters are memoised by [_key], so scrolling the same people back
/// into view re-uses them and a re-selection costs nothing.
class ExploreMarkerImages {
  ExploreMarkerImages();

  /// Logical diameter of the photo disc. The rendered bitmap is larger — see
  /// [_scale] and the room left for glow and tail.
  static const double _size = 54;
  static const double _selectedSize = 62;

  /// Fixed raster scale rather than the device's. A marker is uploaded to the
  /// GPU once and then drawn by MapLibre at whatever size the layer's
  /// `icon-size` asks for, so matching the screen's DPR would only make the
  /// bitmap's crispness depend on which phone generated it.
  ///
  /// The layer divides by this to get back to life size — but by how much
  /// depends on the platform, so ask [iconSizeFor] rather than dividing here.
  static const double rasterScale = 3;
  static const double _scale = rasterScale;

  /// The `icon-size` that draws these rasters at life size on this platform.
  ///
  /// ## The same bitmap is not the same size everywhere
  ///
  /// MapLibre sizes an icon as `bitmapPixels ÷ image.pixelRatio × icon-size`,
  /// and the plugin hands it a different `pixelRatio` on each platform:
  ///
  ///   * **web** — `maplibre_gl_web` passes `{'pixelRatio': 1}` outright, so
  ///     a 162 px bitmap is 162 CSS px.
  ///   * **Android** — the PNG is decoded by `BitmapFactory`, which leaves the
  ///     bitmap stamped with the *device* density; MapLibre reads that back as
  ///     `density ÷ 160`, which is the device pixel ratio.
  ///   * **iOS** — `UIImage(data:scale: UIScreen.main.scale)`, which is the
  ///     device pixel ratio again.
  ///
  /// So a flat `1 / rasterScale` — correct on the web, where these markers
  /// were tuned — came out as `1 / (rasterScale × dpr)` on a phone. On a 3×
  /// screen that is a third of the intended size, which is exactly what "the
  /// faces are tiny on Android" turned out to be.
  ///
  /// Multiplying by the device's own ratio on native cancels the plugin's, and
  /// the same 54 dp disc lands on every platform. It is pixel-perfect where
  /// the ratio and [rasterScale] agree, and merely resampled elsewhere.
  static double iconSizeFor(double devicePixelRatio) =>
      (kIsWeb ? 1.0 : devicePixelRatio) / rasterScale;

  /// Longest a photo fetch may hold up a marker. Past this the person is drawn
  /// with their initial — a marker that is late is worse than one that is
  /// plain, because the map has already settled and people are reading it.
  static const Duration _photoTimeout = Duration(seconds: 6);

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List>> _inFlight = {};

  /// The MapLibre image id for a person in a given state. Also the cache key —
  /// the two must agree or the map draws a stale face.
  static String imageId(MapUser user, {required bool selected}) =>
      _key(user, selected: selected);

  static String _key(MapUser user, {required bool selected}) {
    final photo = user.primaryPhotoUrl ?? '';
    // The photo URL is in the key because a profile-photo change has to
    // invalidate the raster; the online flag because the dot is baked in.
    return 'person.${user.id}.${selected ? 's' : 'n'}'
        '.${user.isOnline ? '1' : '0'}.${photo.hashCode}';
  }

  /// Whether [imageId] is already registered, so callers can skip the await.
  bool has(String id) => _cache.containsKey(id);

  /// Registers the marker every person is drawn with until their own face has
  /// been fetched and rasterised.
  ///
  /// Without it the map is empty for as long as the slowest thumbnail takes,
  /// which on a poor connection is long enough to look broken — and the people
  /// are already positioned, already clustered, already tappable.
  Future<void> registerFallback(
    MapLibreMapController map,
    String id,
  ) async {
    final bytes = _cache[id] ??= await _paint(
      const MapUser(
        card: DiscoveryCard(id: '', displayName: ''),
        latitude: 0,
        longitude: 0,
      ),
      photo: null,
      selected: false,
      anonymous: true,
    );
    await map.addImage(id, bytes);
  }

  /// The bitmap for [user]. Concurrent calls for the same state share one
  /// render rather than racing to produce the same pixels twice.
  Future<Uint8List> build(MapUser user, {bool selected = false}) {
    final key = _key(user, selected: selected);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    return _inFlight[key] ??= _render(user, selected: selected).then((bytes) {
      _cache[key] = bytes;
      _inFlight.remove(key);
      return bytes;
    }, onError: (Object error, StackTrace stack) {
      _inFlight.remove(key);
      throw error;
    });
  }

  Future<Uint8List> _render(MapUser user, {required bool selected}) async {
    final photo = await _loadPhoto(user.primaryPhotoUrl);
    try {
      return await _paint(user, photo: photo, selected: selected);
    } finally {
      photo?.dispose();
    }
  }

  /// Decodes the profile photo, or null when there isn't one, it fails, or it
  /// takes too long.
  Future<ui.Image?> _loadPhoto(String? url) async {
    if (url == null || url.isEmpty) return null;

    final completer = Completer<ui.Image?>();
    // maxWidth caps the decode: a marker is 168 px of bitmap, so decoding a
    // 2000 px portrait to sample it down would be most of the cost of the map.
    final provider = CachedNetworkImageProvider(url, maxWidth: 192);
    final stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    void finish(ui.Image? image) {
      if (!completer.isCompleted) completer.complete(image);
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      // Cloned because the frame belongs to the image cache, which is free to
      // evict and dispose it the moment this listener returns.
      (info, _) => finish(info.image.clone()),
      onError: (_, _) => finish(null),
    );
    stream.addListener(listener);

    return completer.future
        .timeout(_photoTimeout, onTimeout: () {
      stream.removeListener(listener);
      return null;
    });
  }

  Future<Uint8List> _paint(
    MapUser user, {
    required ui.Image? photo,
    required bool selected,
    bool anonymous = false,
  }) async {
    final disc = selected ? _selectedSize : _size;

    // Glow gets more room when selected, and the tail hangs below the disc.
    final glow = selected ? 13.0 : 9.0;
    const tail = 7.0;
    final width = disc + glow * 2;
    final height = disc + glow * 2 + tail;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(_scale);

    final centre = Offset(width / 2, glow + disc / 2);
    final radius = disc / 2;

    _paintGlow(canvas, centre, radius, glow, selected: selected);
    _paintTail(canvas, centre, radius, tail);
    _paintRing(canvas, centre, radius, selected: selected);
    if (anonymous) {
      _paintAnonymous(canvas, centre, radius);
    } else {
      _paintPhoto(canvas, centre, radius, photo: photo, name: user.displayName);
      if (user.isOnline) _paintOnlineDot(canvas, centre, radius);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * _scale).round(),
      (height * _scale).round(),
    );
    picture.dispose();

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// The soft halo. A real radial gradient rather than a blurred copy of the
  /// disc: cheaper, and it fades to nothing at the edge so markers overlapping
  /// in a dense area don't build up a grey smear between them.
  void _paintGlow(
    ui.Canvas canvas,
    Offset centre,
    double radius,
    double glow, {
    required bool selected,
  }) {
    final outer = radius + glow;
    canvas.drawCircle(
      centre,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppMapColors.glow.withValues(alpha: selected ? 0.55 : 0.32),
            AppMapColors.glow.withValues(alpha: 0),
          ],
          stops: const [0.62, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: outer)),
    );
  }

  /// The little point that pins the marker to its spot. With `icon-anchor:
  /// bottom` this tip is what sits on the coordinate, so a tilted map reads the
  /// marker as standing on the ground rather than hovering over it.
  void _paintTail(
    ui.Canvas canvas,
    Offset centre,
    double radius,
    double tail,
  ) {
    final path = Path()
      ..moveTo(centre.dx - 5.2, centre.dy + radius - 2)
      ..lineTo(centre.dx, centre.dy + radius + tail)
      ..lineTo(centre.dx + 5.2, centre.dy + radius - 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppMapColors.markerEnd, AppMapColors.markerStart],
        ).createShader(
          Rect.fromLTWH(
            centre.dx - 6,
            centre.dy + radius - 2,
            12,
            tail + 2,
          ),
        ),
    );
  }

  /// Gradient ring, then the white band that separates a photo from the map.
  void _paintRing(
    ui.Canvas canvas,
    Offset centre,
    double radius, {
    required bool selected,
  }) {
    final ringWidth = selected ? 3.4 : 2.6;
    canvas.drawCircle(
      centre,
      radius - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..shader = const SweepGradient(
          // Starts at the top and comes back round, so the blue-to-violet
          // sweep reads as one continuous ring instead of a seam.
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [
            AppMapColors.markerStart,
            AppMapColors.markerEnd,
            AppMapColors.markerStart,
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawCircle(
      centre,
      radius - ringWidth - 0.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = AppColors.onImage,
    );
  }

  void _paintPhoto(
    ui.Canvas canvas,
    Offset centre,
    double radius, {
    required ui.Image? photo,
    required String name,
  }) {
    final inner = radius - 4.6;
    final bounds = Rect.fromCircle(center: centre, radius: inner);

    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));

    if (photo == null) {
      _paintInitial(canvas, bounds, name);
    } else {
      // BoxFit.cover by hand — paintImage() needs a full painting context and
      // this is the only fit a round crop of a portrait ever wants.
      final source = _coverRect(
        photo.width.toDouble(),
        photo.height.toDouble(),
        bounds,
      );
      canvas.drawImageRect(
        photo,
        source,
        bounds,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    canvas.restore();
  }

  /// The stand-in when there is no photo: the app's blue-to-violet gradient
  /// with the person's initial, matching what the Radar grid already shows.
  void _paintInitial(ui.Canvas canvas, Rect bounds, String name) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppMapColors.markerStart, AppMapColors.markerEnd],
        ).createShader(bounds),
    );

    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final painter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          // Not AppTextStyles.avatarInitial: this paints onto a raw canvas
          // with no font fallback resolution behind it, and Fraunces is a
          // variable font whose metrics here would need the same clamping the
          // token does. The marker only ever shows one capital.
          fontFamily: 'Fraunces',
          fontSize: bounds.width * 0.44,
          height: 1,
          fontWeight: FontWeight.w600,
          color: AppColors.onImage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      bounds.center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  /// The placeholder face: the gradient with a person glyph rather than an
  /// initial, so it never reads as somebody actually called "?".
  void _paintAnonymous(ui.Canvas canvas, Offset centre, double radius) {
    final inner = radius - 4.6;
    final bounds = Rect.fromCircle(center: centre, radius: inner);
    canvas.drawCircle(
      centre,
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppMapColors.markerStart.withValues(alpha: 0.85),
            AppMapColors.markerEnd.withValues(alpha: 0.85),
          ],
        ).createShader(bounds),
    );

    // Head and shoulders, drawn rather than pulled from an icon font — a font
    // glyph here would need the same fallback resolution a raw canvas lacks.
    final head = inner * 0.27;
    canvas.drawCircle(
      centre.translate(0, -inner * 0.18),
      head,
      Paint()..color = AppColors.onImage.withValues(alpha: 0.9),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: centre.translate(0, inner * 0.62),
        width: inner * 1.15,
        height: inner * 1.0,
      ),
      math.pi,
      math.pi,
      false,
      Paint()..color = AppColors.onImage.withValues(alpha: 0.9),
    );
  }

  void _paintOnlineDot(ui.Canvas canvas, Offset centre, double radius) {
    // 45° down-right of centre, just inside the ring.
    final offset = radius * 0.72;
    final at = centre + Offset(offset, offset) / math.sqrt2 * 1.06;
    canvas.drawCircle(at, 5.4, Paint()..color = AppColors.onImage);
    canvas.drawCircle(at, 3.7, Paint()..color = AppColors.ok);
  }

  /// The largest centred source rect of a [width]×[height] image that fills
  /// [destination] without distorting it.
  static Rect _coverRect(double width, double height, Rect destination) {
    final scale = math.max(
      destination.width / width,
      destination.height / height,
    );
    final visibleWidth = destination.width / scale;
    final visibleHeight = destination.height / scale;
    return Rect.fromLTWH(
      (width - visibleWidth) / 2,
      // Portraits are cropped from the top third rather than the middle:
      // faces sit high in a profile photo, and a centred crop of a
      // full-length shot is reliably a picture of somebody's chest.
      (height - visibleHeight) * 0.28,
      visibleWidth,
      visibleHeight,
    );
  }

  /// Drops every raster. Called when the screen goes away — these are GPU
  /// textures on the MapLibre side and PNG buffers on ours, and a session of
  /// browsing at 100 people a page has no reason to keep either.
  void dispose() {
    _cache.clear();
    _inFlight.clear();
  }
}
