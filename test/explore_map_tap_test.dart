import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/presentation/explore/marker_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Picking somebody on the map, and what the map does about it.
///
/// Both halves shipped broken. Selecting hid the crowd before the selected
/// marker existed, so tapping a face emptied the map; and the tap itself was
/// resolved only through `queryRenderedFeatures`, which answers a request
/// naming a layer it does not know with a console error and an empty list.
MapUser _person(String id, {double lat = 13.6288, double lng = 79.4192}) =>
    MapUser(
      card: DiscoveryCard(id: id, displayName: id),
      latitude: lat,
      longitude: lng,
    );

/// The id a filter pins to, or null if it pins to nothing.
String? _pinnedId(List<Object> filter) {
  if (filter.isEmpty || filter.first != 'all') return null;
  for (final clause in filter.skip(1)) {
    if (clause is List && clause.length == 3 && clause.first == '==') {
      final field = clause[1];
      if (field is List && field.length == 2 && field[1] == 'id') {
        return clause[2] as String?;
      }
    }
  }
  return null;
}

bool _drawsNothing(List<Object> filter) =>
    filter.toString() == matchNothingFilter.toString();

bool _drawsEveryone(List<Object> filter) =>
    filter.toString() == unclusteredFilter.toString();

void main() {
  group('peopleLayerFilters', () {
    test('shows the whole crowd when nobody is picked', () {
      final f = peopleLayerFilters(selectedId: null, ready: false);

      expect(_drawsEveryone(f.base), isTrue);
      expect(_drawsNothing(f.selected), isTrue);
      expect(_drawsEveryone(f.ground), isTrue);
      expect(f.clusters, const ['has', 'point_count']);
    });

    test('keeps the picked person visible before their raster exists', () {
      // The bug: `base` was emptied the instant somebody was picked, while
      // `selected` could not draw them yet — so the map went blank on tap.
      final f = peopleLayerFilters(selectedId: 'emma', ready: false);

      expect(_pinnedId(f.base), 'emma');
      expect(_drawsNothing(f.selected), isTrue);
      expect(_pinnedId(f.ground), 'emma');
    });

    test('hands over to the selected layer once the raster lands', () {
      final f = peopleLayerFilters(selectedId: 'emma', ready: true);

      expect(_drawsNothing(f.base), isTrue);
      expect(_pinnedId(f.selected), 'emma');
      expect(_pinnedId(f.ground), 'emma');
    });

    test('always draws the picked person exactly once', () {
      // The invariant behind both cases above: whatever the raster is doing,
      // one layer and only one layer is responsible for them.
      for (final ready in [false, true]) {
        final f = peopleLayerFilters(selectedId: 'emma', ready: ready);
        final drawing = [
          if (_pinnedId(f.base) == 'emma') 'base',
          if (_pinnedId(f.selected) == 'emma') 'selected',
        ];
        expect(drawing, hasLength(1), reason: 'ready: $ready');
      }
    });

    test('hides clusters while one person is in focus', () {
      // A "1" bubble beside the only person on the map would be nonsense.
      final f = peopleLayerFilters(selectedId: 'emma', ready: true);
      expect(_drawsNothing(f.clusters), isTrue);
    });

    test('labels every face with its distance while nobody is picked', () {
      // The whole point of the label: how far away somebody is, without
      // having to select them to find out.
      final f = peopleLayerFilters(selectedId: null, ready: false);
      expect(_drawsEveryone(f.distance), isTrue);
    });

    test('drops the labels once one person is in focus', () {
      // The focus pill over the composer already prints their distance, and
      // the selected marker is a larger raster than the offsets assume.
      for (final ready in [false, true]) {
        final f = peopleLayerFilters(selectedId: 'emma', ready: ready);
        expect(_drawsNothing(f.distance), isTrue, reason: 'ready: $ready');
      }
    });

    test('never lets a null id pin a layer to a real person', () {
      final f = peopleLayerFilters(selectedId: null, ready: true);
      expect(_pinnedId(f.selected), isNot('emma'));
      expect(_drawsNothing(f.selected), isTrue);
    });
  });

  group('personNearTap', () {
    final people = [
      _person('emma', lat: 13.6288, lng: 79.4192),
      _person('jason', lat: 13.6500, lng: 79.4500),
    ];
    final drawn = {
      for (final person in people)
        person.id: LatLng(person.latitude, person.longitude),
    };

    MapUser? resolve(LatLng tap, {double zoom = 16, bool focused = false}) =>
        personNearTap(
          tap: tap,
          people: people,
          drawn: drawn,
          zoom: zoom,
          clusterMaxZoom: 14,
          focused: focused,
        );

    test('finds the marker under the tap', () {
      expect(resolve(const LatLng(13.6288, 79.4192))?.id, 'emma');
    });

    test('tolerates a tap a few pixels off', () {
      // ~11 m north at zoom 16 is a couple of pixels — well inside a marker.
      expect(resolve(const LatLng(13.6289, 79.4192))?.id, 'emma');
    });

    test('picks the nearer of two markers', () {
      expect(resolve(const LatLng(13.6495, 79.4495))?.id, 'jason');
    });

    test('ignores a tap on empty map', () {
      expect(resolve(const LatLng(13.7500, 79.5500)), isNull);
    });

    test('declines while the map is clustered', () {
      // The nearest person may be rolled up inside a cluster the user was
      // actually aiming at; expanding it is the cluster branch's job.
      expect(resolve(const LatLng(13.6288, 79.4192), zoom: 12), isNull);
    });

    test('still answers at a clustered zoom once somebody is in focus', () {
      // Focused means there are no clusters on screen to compete with.
      expect(
        resolve(const LatLng(13.6288, 79.4192), zoom: 12, focused: true)?.id,
        'emma',
      );
    });

    test('the tolerance follows the zoom', () {
      // ~110 m away: within a marker's width when pulled back, nowhere near it
      // up close. A fixed metre tolerance would be wrong at one end or other.
      const tap = LatLng(13.6298, 79.4192);
      expect(resolve(tap, zoom: 15, focused: true)?.id, 'emma');
      expect(resolve(tap, zoom: 19, focused: true), isNull);
    });

    test('skips anybody without a drawn position', () {
      expect(
        personNearTap(
          tap: const LatLng(13.6288, 79.4192),
          people: people,
          drawn: const {},
          zoom: 16,
          clusterMaxZoom: 14,
          focused: false,
        ),
        isNull,
      );
    });
  });
}
