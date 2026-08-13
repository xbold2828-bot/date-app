import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../data/models/map_user_model.dart';

/// Where each person's marker is actually drawn.
///
/// ## The problem this solves
///
/// The backend generalizes every map position onto a ~500 m grid, which is
/// what stops a marker from being an address. In a dense city that reliably
/// puts several people on *exactly* the same coordinate — and a marker
/// perfectly covering another marker is a person who cannot be tapped, seen or
/// reached at all. They are on the map and unreachable, which is worse than
/// being absent.
///
/// So co-located people are pushed onto a small ring inside their own grid
/// cell. Three properties matter:
///
///   * **Stable.** Offsets come from the sorted ids, not from iteration order
///     or a random seed, so a refresh redraws the same arrangement instead of
///     shuffling everyone around the map.
///   * **Contained.** The ring is well inside the 0.005° cell the backend
///     snapped to, so nobody is nudged into a neighbouring cell and no one is
///     moved far enough to change which band they read as.
///   * **Presentational only.** The coordinate being adjusted is already a
///     deliberate fiction. This reveals nothing, because there is nothing left
///     in it to reveal.
///
/// Kept out of the map widget so it can be tested as what it is: a pure
/// function from people to points.
Map<String, LatLng> spreadColocated(List<MapUser> users) {
  final byCell = <String, List<MapUser>>{};
  for (final user in users) {
    // Four decimals ≈ 11 m, comfortably finer than the grid the backend snaps
    // to, so this groups exact collisions and nothing else.
    final key = '${user.latitude.toStringAsFixed(4)},'
        '${user.longitude.toStringAsFixed(4)}';
    byCell.putIfAbsent(key, () => []).add(user);
  }

  final result = <String, LatLng>{};
  for (final group in byCell.values) {
    if (group.length == 1) {
      final only = group.single;
      result[only.id] = LatLng(only.latitude, only.longitude);
      continue;
    }

    group.sort((a, b) => a.id.compareTo(b.id));

    // Concentric rings, each holding proportionally more people than the one
    // inside it (`_perRing * r`), so spacing stays even as a cell fills rather
    // than crowding the innermost ring.
    final rings = _ringsFor(group.length);
    // The outermost ring is pinned to the widest safe radius, and the rest
    // divide the space inside it. Without this, a crowded cell simply grew
    // outwards until its outer ring escaped into a neighbour's square.
    final step = _maxRadiusDegrees / rings;

    var index = 0;
    for (var ring = 1; ring <= rings && index < group.length; ring++) {
      final slots = math.min(_perRing * ring, group.length - index);
      final radius = step * ring;
      for (var slot = 0; slot < slots; slot++, index++) {
        final user = group[index];
        // Each ring is rotated against the one inside it, so a person on the
        // outer ring never sits directly behind a person on the inner one.
        final angle = 2 * math.pi * slot / slots + ring * 0.4;
        final latitude = user.latitude + radius * math.cos(angle);
        // Longitude degrees narrow towards the poles; without this correction
        // the ring flattens into an ellipse the further north it is drawn.
        final longitude = user.longitude +
            radius *
                math.sin(angle) /
                math.max(math.cos(user.latitude * math.pi / 180), 0.2);
        result[user.id] = LatLng(latitude, longitude);
      }
    }
  }
  return result;
}

/// How many rings [count] people need, at `_perRing * r` people on ring r.
/// Capacity after R rings is `_perRing * R * (R + 1) / 2`.
int _ringsFor(int count) {
  var rings = 1;
  var capacity = _perRing;
  while (capacity < count) {
    rings++;
    capacity += _perRing * rings;
  }
  return rings;
}

/// Widest a marker may be pushed from its generalized position, in degrees of
/// latitude — about 240 m.
///
/// Under half the backend's 0.005° grid cell, which is the hard constraint:
/// past that a person is drawn inside somebody else's square, and far enough
/// to read as a different distance band than the one their card claims.
const double _maxRadiusDegrees = 0.0022;

const int _perRing = 6;

/// Where the camera has to sit for every point to be on screen at once.
class CameraFrame {
  const CameraFrame({required this.centre, required this.zoom});

  final LatLng centre;
  final double zoom;
}

/// Frame the camera around everyone on the map.
///
/// ## Why this exists
///
/// The first version of Explore opened at a fixed zoom, which on a phone-width
/// viewport covers roughly ±3.4 km — while the radius filter goes up to
/// "10 km+". With a wide radius the request was right, the header counted the
/// right people, and every one of them was rendered off screen. The map looked
/// empty, and nothing about an empty map suggests scrolling to find anyone.
///
/// Fitting to the actual result set fixes that for every band at once, and
/// keeps working if the bands are ever changed.
///
/// Deliberately not `CameraUpdate.newLatLngBounds`, which does this on the
/// platform side but resets tilt and bearing to zero — that would flatten the
/// 3D view every time the radius changed.
///
/// Returns null when there is nothing to frame or the viewport is not laid out.
CameraFrame? frameFor(
  List<LatLng> points, {
  required Size viewport,
  required double minZoom,
  required double maxZoom,
  required double soloZoom,
  bool tilted = false,
  double chromeTop = 150,
  double chromeBottom = 210,
  double chromeSide = 48,
}) {
  if (points.isEmpty || viewport.isEmpty) return null;
  if (points.length == 1) {
    return CameraFrame(centre: points.single, zoom: soloZoom);
  }

  var south = points.first.latitude;
  var north = points.first.latitude;
  var west = points.first.longitude;
  var east = points.first.longitude;
  for (final point in points) {
    south = math.min(south, point.latitude);
    north = math.max(north, point.latitude);
    west = math.min(west, point.longitude);
    east = math.max(east, point.longitude);
  }

  final centre = LatLng(
    // Mercator midpoint rather than the arithmetic mean. Over a 20 km span the
    // two differ by metres, but the same code has to stay right if the span is
    // ever continental.
    _inverseMercator((_mercator(south) + _mercator(north)) / 2),
    (west + east) / 2,
  );

  // Room for the header and radius pills above and a profile preview below, so
  // nobody is framed underneath a card that is covering them.
  final usableWidth = math.max(viewport.width - chromeSide * 2, 80.0);
  final usableHeight =
      math.max(viewport.height - chromeTop - chromeBottom, 80.0);

  const tileSize = 256.0;
  final latitudeFraction =
      (_mercator(north) - _mercator(south)).abs() / (2 * math.pi);
  final longitudeFraction = (east - west).abs() / 360;

  // A span that is degenerate in one axis — everybody on the same latitude —
  // must not drive that axis's zoom to infinity.
  final candidates = <double>[
    if (latitudeFraction > 1e-9)
      _log2(usableHeight / tileSize / latitudeFraction),
    if (longitudeFraction > 1e-9)
      _log2(usableWidth / tileSize / longitudeFraction),
  ];
  if (candidates.isEmpty) {
    return CameraFrame(centre: centre, zoom: soloZoom);
  }

  var zoom = candidates.reduce(math.min);
  // Tilting throws the far edge of the frame towards the horizon, so less
  // ground is visible than the flat projection implies.
  if (tilted) zoom -= 0.6;

  return CameraFrame(centre: centre, zoom: zoom.clamp(minZoom, maxZoom));
}

double _mercator(double latitude) {
  final clamped = latitude.clamp(-85.05112878, 85.05112878);
  return math.log(math.tan(math.pi / 4 + (clamped * math.pi / 180) / 2));
}

double _inverseMercator(double y) =>
    (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

double _log2(double value) => math.log(value) / math.ln2;
