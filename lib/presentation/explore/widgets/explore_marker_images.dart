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
/// Markers are images rather than Flutter widgets so they stay attached to the
/// ground while the map pans, rotates and tilts. Appearance and selection are
/// animated on the whole layer, not per marker.
///
/// Each person is rendered once per state and cached, and photos are loaded
/// through [CachedNetworkImageProvider] with a width cap so only thumbnails
/// are decoded.
class ExploreMarkerImages {
  ExploreMarkerImages();

  /// Logical diameter of the photo disc.
  static const double _size = 54;
  static const double _selectedSize = 62;

  /// Fixed raster scale, so marker sharpness does not depend on the phone that
  /// generated it.
  static const double rasterScale = 3;
  static const double _scale = rasterScale;

  /// The `icon-size` that draws a marker at life size on this platform.
  ///
  /// MapLibre divides the bitmap by a pixel ratio that differs per platform:
  /// 1 on web, the device pixel ratio on Android and iOS. Multiplying by the
  /// device ratio on native cancels that out, so the marker is the same size
  /// everywhere.
  static double iconSizeFor(double devicePixelRatio) =>
      (kIsWeb ? 1.0 : devicePixelRatio) / rasterScale;

  /// Longest a photo may delay a marker before the initial is drawn instead.
  static const Duration _photoTimeout = Duration(seconds: 6);

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List>> _inFlight = {};

  /// MapLibre image id for a person in a given state. Also the cache key, so
  /// the two always agree.
  static String imageId(MapUser user, {required bool selected}) =>
      _key(user, selected: selected);

  static String _key(MapUser user, {required bool selected}) {
    final photo = user.primaryPhotoUrl ?? '';
    // The photo and the online flag are part of the key because both are
    // baked into the bitmap.
    return 'person.${user.id}.${selected ? 's' : 'n'}'
        '.${user.isOnline ? '1' : '0'}.${photo.hashCode}';
  }

  bool has(String id) => _cache.containsKey(id);

  /// Registers the generic marker shown until a person's photo has loaded, so
  /// the map is never empty while thumbnails download.
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
  /// render.
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

  /// Decodes the profile photo, or returns null when there is none, it fails,
  /// or it takes too long.
  Future<ui.Image?> _loadPhoto(String? url) async {
    if (url == null || url.isEmpty) return null;

    final completer = Completer<ui.Image?>();
    final provider = CachedNetworkImageProvider(url, maxWidth: 192);
    final stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    void finish(ui.Image? image) {
      if (!completer.isCompleted) completer.complete(image);
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      // Cloned because the image cache may dispose the original right away.
          (info, _) => finish(info.image.clone()),
      onError: (_, _) => finish(null),
    );
    stream.addListener(listener);

    return completer.future.timeout(_photoTimeout, onTimeout: () {
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

  /// Flat, faint blue halo behind the marker.
  void _paintGlow(
      ui.Canvas canvas,
      Offset centre,
      double radius,
      double glow, {
        required bool selected,
      }) {
    canvas.drawCircle(
      centre,
      radius + glow,
      Paint()..color = AppColors.blue.withValues(alpha: selected ? 0.22 : 0.14),
    );
  }

  /// The small point that pins the marker to its coordinate.
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
    canvas.drawPath(path, Paint()..color = AppColors.blue);
  }

  /// Blue ring, then a thin white band that separates the photo from it.
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
        ..color = AppColors.blue,
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

  /// Fallback when there is no photo: the person's initial on solid blue.
  void _paintInitial(ui.Canvas canvas, Rect bounds, String name) {
    canvas.drawRect(bounds, Paint()..color = AppColors.blue);

    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final painter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
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

  /// Generic face shown before anyone's photo loads: a person silhouette on
  /// solid blue.
  void _paintAnonymous(ui.Canvas canvas, Offset centre, double radius) {
    final inner = radius - 4.6;
    canvas.drawCircle(centre, inner, Paint()..color = AppColors.blue);

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
    final offset = radius * 0.72;
    final at = centre + Offset(offset, offset) / math.sqrt2 * 1.06;
    canvas.drawCircle(at, 5.4, Paint()..color = AppColors.onImage);
    canvas.drawCircle(at, 3.7, Paint()..color = AppColors.ok);
  }

  /// Largest centred source rect that fills [destination] without distortion,
  /// shifted toward the top because faces sit high in profile photos.
  static Rect _coverRect(double width, double height, Rect destination) {
    final scale = math.max(
      destination.width / width,
      destination.height / height,
    );
    final visibleWidth = destination.width / scale;
    final visibleHeight = destination.height / scale;
    return Rect.fromLTWH(
      (width - visibleWidth) / 2,
      (height - visibleHeight) * 0.28,
      visibleWidth,
      visibleHeight,
    );
  }

  /// Drops every cached raster when the screen goes away.
  void dispose() {
    _cache.clear();
    _inFlight.clear();
  }
}