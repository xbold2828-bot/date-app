import 'dart:math' as math;

import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/presentation/explore/marker_layout.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// The backend snaps every map position onto a ~500 m grid, so exact
/// collisions are normal rather than exotic — and a marker perfectly hidden
/// under another marker is a person the map has silently removed.
void main() {
  MapUser at(String id, double latitude, double longitude) => MapUser(
        card: DiscoveryCard(id: id, displayName: id),
        latitude: latitude,
        longitude: longitude,
      );

  /// Metres between two nearby points. Good enough at these distances.
  double metresBetween(double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * 111000;
    final dLng =
        (lng2 - lng1) * 111000 * math.cos(lat1 * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  // `LatLng` renormalises longitude on construction, which costs a few
  // femtodegrees of floating-point drift. That is nanometres on the ground, so
  // "unmoved" is asserted to a tolerance rather than to the bit.
  const unmoved = 1e-9;

  test('leaves someone standing alone where the backend put them', () {
    final drawn = spreadColocated([at('a', 12.97, 77.59)]);

    expect(drawn['a']!.latitude, closeTo(12.97, unmoved));
    expect(drawn['a']!.longitude, closeTo(77.59, unmoved));
  });

  test('gives every co-located person a distinct point', () {
    final drawn = spreadColocated([
      for (var i = 0; i < 5; i++) at('u$i', 12.97, 77.59),
    ]);

    final points = drawn.values
        .map((p) => '${p.latitude},${p.longitude}')
        .toSet();
    expect(points, hasLength(5));
  });

  test('separates them by enough to tap', () {
    final drawn = spreadColocated([
      for (var i = 0; i < 4; i++) at('u$i', 12.97, 77.59),
    ]);

    final points = drawn.values.toList();
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final gap = metresBetween(
          points[i].latitude,
          points[i].longitude,
          points[j].latitude,
          points[j].longitude,
        );
        // At the zoom where clustering hands over, a marker is a few tens of
        // metres wide. Anything under that overlaps again.
        expect(gap, greaterThan(60), reason: 'markers $i and $j overlap');
      }
    }
  });

  test('keeps everyone inside their own grid cell', () {
    const cell = 0.005; // the backend's snap, in degrees
    final drawn = spreadColocated([
      for (var i = 0; i < 14; i++) at('u$i', 12.97, 77.59),
    ]);

    for (final point in drawn.values) {
      // Half a cell would already be somebody else's square, and a person
      // nudged out of their band is a person the map has misplaced.
      expect((point.latitude - 12.97).abs(), lessThan(cell / 2));
      expect((point.longitude - 77.59).abs(), lessThan(cell / 2));
    }
  });

  test('is stable across refreshes regardless of arrival order', () {
    final forwards = spreadColocated([
      at('a', 12.97, 77.59),
      at('b', 12.97, 77.59),
      at('c', 12.97, 77.59),
    ]);
    final backwards = spreadColocated([
      at('c', 12.97, 77.59),
      at('b', 12.97, 77.59),
      at('a', 12.97, 77.59),
    ]);

    // Otherwise every reload shuffles the same people around the map, and a
    // marker somebody was reaching for moves out from under their finger.
    for (final id in ['a', 'b', 'c']) {
      expect(forwards[id]!.latitude, backwards[id]!.latitude);
      expect(forwards[id]!.longitude, backwards[id]!.longitude);
    }
  });

  test('does not disturb people who were never co-located', () {
    final drawn = spreadColocated([
      at('a', 12.970, 77.590),
      at('b', 12.975, 77.595),
    ]);

    expect(drawn['a']!.latitude, closeTo(12.970, unmoved));
    expect(drawn['b']!.longitude, closeTo(77.595, unmoved));
  });

  test('spreads onto more than one ring once a cell is crowded', () {
    final drawn = spreadColocated([
      for (var i = 0; i < 13; i++) at('u$i', 12.97, 77.59),
    ]);

    expect(drawn, hasLength(13));
    // Distance from the shared centre, rounded to the metre. A single ring of
    // thirteen would crowd its neighbours; two or more distinct radii means
    // the layout expanded outwards instead.
    final radii = drawn.values
        .map((p) => (metresBetween(12.97, 77.59, p.latitude, p.longitude))
            .round())
        .toSet();
    expect(radii.length, greaterThan(1));
  });

  test('keeps the whole backend page inside its cells', () {
    // The endpoint caps itself at 100 people, and a bad enough day puts a lot
    // of them in the same square.
    const cell = 0.005;
    final drawn = spreadColocated([
      for (var i = 0; i < 100; i++) at('u$i', 12.97, 77.59),
    ]);

    expect(drawn, hasLength(100));
    for (final point in drawn.values) {
      expect((point.latitude - 12.97).abs(), lessThan(cell / 2));
    }
  });

  test('corrects for longitude degrees narrowing away from the equator', () {
    final tropics = spreadColocated([
      for (var i = 0; i < 4; i++) at('u$i', 5.0, 0.0),
    ]);
    final north = spreadColocated([
      for (var i = 0; i < 4; i++) at('u$i', 60.0, 0.0),
    ]);

    double widthOf(Map<String, dynamic> points) {
      final longitudes =
          points.values.map((p) => p.longitude as double).toList();
      return longitudes.reduce(math.max) - longitudes.reduce(math.min);
    }

    // Same ring in metres means a wider spread in degrees the further north
    // it is — without the correction the ring would flatten into a line.
    expect(widthOf(north), greaterThan(widthOf(tropics)));
  });

  _cameraFrameTests();

  test('handles an empty map', () {
    expect(spreadColocated(const []), isEmpty);
  });
}

/// Framing the camera. The bug this covers shipped: Explore opened at a fixed
/// zoom regardless of how wide the radius filter was set, so with "10 km+"
/// selected the header counted the right people and every one of them was
/// rendered off screen.
void _cameraFrameTests() {
  const viewport = Size(511, 838); // the reported phone-width browser window

  CameraFrame? frame(List<LatLng> points, {bool tilted = false}) => frameFor(
        points,
        viewport: viewport,
        minZoom: 3,
        maxZoom: 15.5,
        soloZoom: 13.5,
        tilted: tilted,
      );

  /// Half the ground the viewport covers at [zoom], in km, on the short axis.
  double halfWidthKm(double zoom, double latitude) {
    final metresPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    return metresPerPixel * viewport.width / 2000;
  }

  group('frameFor', () {
    test('nothing to frame is not a frame', () {
      expect(frame(const []), isNull);
      expect(
        frameFor(
          [const LatLng(13.6, 79.4)],
          viewport: Size.zero,
          minZoom: 3,
          maxZoom: 15.5,
          soloZoom: 13.5,
        ),
        isNull,
      );
    });

    test('a lone point keeps the default zoom', () {
      final only = frame([const LatLng(13.6, 79.4)])!;
      expect(only.zoom, 13.5);
      expect(only.centre.latitude, closeTo(13.6, 1e-9));
    });

    test('pulls back far enough to hold a 10 km radius', () {
      // The reported bug, as a test. People spread across ±10 km of the viewer
      // must all be inside the frame the camera picks.
      const me = LatLng(13.6288, 79.4192);
      final people = [
        me,
        const LatLng(13.7190, 79.4192), // ~10 km north
        const LatLng(13.5386, 79.4192), // ~10 km south
        const LatLng(13.6288, 79.5117), // ~10 km east
        const LatLng(13.6288, 79.3267), // ~10 km west
      ];

      final framed = frame(people)!;
      expect(framed.centre.latitude, closeTo(13.6288, 0.01));

      // At the old fixed 13.5 the viewport held ±3.4 km, so this must be well
      // below that — and it must actually contain the span.
      expect(framed.zoom, lessThan(12.5));
      expect(halfWidthKm(framed.zoom, 13.6288), greaterThan(10));
    });

    test('stays close when everybody genuinely is close', () {
      // The opposite failure: fitting must not zoom out for a tight group.
      final framed = frame([
        const LatLng(13.6288, 79.4192),
        const LatLng(13.6300, 79.4205),
      ])!;
      expect(framed.zoom, greaterThan(13));
    });

    test('never zooms in past the tap-to-focus zoom', () {
      // Two people a few metres apart would otherwise fit at zoom 20-something,
      // which arrives inside a building.
      final framed = frame([
        const LatLng(13.62880, 79.41920),
        const LatLng(13.62881, 79.41921),
      ])!;
      expect(framed.zoom, lessThanOrEqualTo(15.5));
    });

    test('leaves room for the chrome floating over the map', () {
      // A frame computed against the raw viewport would tuck the northernmost
      // person under the header. Compare against an unpadded fit: the padded
      // one has to be further back.
      const people = [LatLng(13.55, 79.40), LatLng(13.70, 79.44)];
      final padded = frame(people)!;
      final unpadded = frameFor(
        people,
        viewport: viewport,
        minZoom: 3,
        maxZoom: 15.5,
        soloZoom: 13.5,
        chromeTop: 0,
        chromeBottom: 0,
        chromeSide: 0,
      )!;
      expect(padded.zoom, lessThan(unpadded.zoom));
    });

    test('pulls back a little further when tilted', () {
      // Pitch throws the far edge towards the horizon, so a flat fit overshoots.
      const people = [LatLng(13.55, 79.40), LatLng(13.70, 79.44)];
      expect(
        frame(people, tilted: true)!.zoom,
        lessThan(frame(people)!.zoom),
      );
    });

    test('survives everybody sharing a latitude', () {
      // A zero-height span would drive the latitude axis to infinite zoom.
      final framed = frame([
        const LatLng(13.6288, 79.30),
        const LatLng(13.6288, 79.55),
      ])!;
      expect(framed.zoom.isFinite, isTrue);
      expect(framed.zoom, lessThanOrEqualTo(15.5));
      expect(halfWidthKm(framed.zoom, 13.6288), greaterThan(13));
    });

    test('never zooms out past the map minimum', () {
      final framed = frame([
        const LatLng(-70, -170),
        const LatLng(70, 170),
      ])!;
      expect(framed.zoom, greaterThanOrEqualTo(3));
    });
  });
}
