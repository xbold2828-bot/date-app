import 'dart:convert';

import 'package:dating_app/core/constants/app_colors.dart';
import 'package:dating_app/data/services/map_style_service.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The Explore style is a JSON asset, which means the Dart analyzer can see
/// nothing wrong with it. Every mistake it can hold — a typo'd source layer, a
/// colour that drifted from the palette, an extrusion that quietly stopped
/// being an extrusion — ships silently and shows up as a map that renders
/// *something*, just not the right thing. These tests are the compiler the
/// asset does not have.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> style;
  late List<Map<String, dynamic>> layers;

  setUpAll(() async {
    final raw = await rootBundle.loadString(MapStyleService.assetPath);
    style = jsonDecode(raw) as Map<String, dynamic>;
    layers = (style['layers'] as List).cast<Map<String, dynamic>>();
  });

  Map<String, dynamic> layer(String id) =>
      layers.firstWhere((l) => l['id'] == id);

  String paint(String layerId, String property) =>
      (layer(layerId)['paint'] as Map)[property] as String;

  group('style document', () {
    test('is a v8 style with one vector source', () {
      expect(style['version'], 8);
      final sources = style['sources'] as Map;
      expect(sources, hasLength(1));
      expect((sources['openmaptiles'] as Map)['type'], 'vector');
    });

    test('carries the placeholders the service substitutes', () {
      // If the asset renames these, MapStyleService silently ships a style
      // whose tile URL is the literal text "{{TILES_URL}}".
      expect(
        (style['sources']['openmaptiles'] as Map)['url'],
        MapStyleService.tilesPlaceholder,
      );
      expect(style['glyphs'], MapStyleService.glyphsPlaceholder);
    });

    test('addresses only real OpenMapTiles source layers', () {
      // The whole point of the schema is that the provider is swappable. A
      // layer naming something outside it renders nothing on every provider —
      // and renders nothing *quietly*.
      const schema = {
        'water',
        'waterway',
        'water_name',
        'landcover',
        'landuse',
        'park',
        'boundary',
        'transportation',
        'transportation_name',
        'building',
        'place',
        'poi',
        'aeroway',
        'housenumber',
        'mountain_peak',
      };
      for (final l in layers) {
        final sourceLayer = l['source-layer'];
        if (sourceLayer == null) continue;
        expect(
          schema,
          contains(sourceLayer),
          reason: 'layer "${l['id']}" reads an unknown source layer',
        );
      }
    });

    test('every layer except background names the vector source', () {
      for (final l in layers) {
        if (l['type'] == 'background') continue;
        expect(
          l['source'],
          'openmaptiles',
          reason: 'layer "${l['id']}" has no source',
        );
      }
    });

    test('layer ids are unique', () {
      final ids = layers.map((l) => l['id']).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('terrain palette matches AppMapColors', () {
    // Dart cannot reach inside the JSON, so the two definitions of "pastel
    // green park" can drift apart without anything complaining. This is what
    // complains.
    String hex(Color color) =>
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    test('background is the land colour', () {
      expect(paint('background', 'background-color').toUpperCase(),
          hex(AppMapColors.land));
    });

    test('parks and woodland are the pastel greens', () {
      expect(paint('landcover-grass', 'fill-color').toUpperCase(),
          hex(AppMapColors.park));
      expect(paint('landcover-wood', 'fill-color').toUpperCase(),
          hex(AppMapColors.woodland));
      expect(paint('park', 'fill-color').toUpperCase(),
          hex(AppMapColors.woodland));
    });

    test('waterways are the pastel blue', () {
      expect(paint('waterway', 'line-color').toUpperCase(),
          hex(AppMapColors.waterway));
    });

    test('roads run highway → primary → secondary → minor', () {
      // A hierarchy that lives only in the widths is not one anyone can see,
      // so every level has to differ in colour too.
      final colours = [
        for (final id in ['road-primary', 'road-secondary', 'road-minor'])
          paint(id, 'line-color').toUpperCase(),
      ];
      expect(colours.toSet(), hasLength(colours.length));

      expect(colours.first, hex(AppMapColors.roadMajor));
      expect(colours.last, hex(AppMapColors.roadMinor));
    });

    test('highways are the coral, and nothing else is', () {
      // The one warm colour on the map. If a normal road picked it up, the
      // motorway would stop being the thing your eye goes to.
      final highway = jsonEncode(layer('highway')['paint']['line-color'])
          .toUpperCase();
      expect(highway, contains(hex(AppMapColors.highway).substring(1)));

      for (final id in ['road-primary', 'road-secondary', 'road-minor']) {
        expect(
          paint(id, 'line-color').toUpperCase(),
          isNot(hex(AppMapColors.highway)),
        );
      }
    });

    test('labels are charcoal rather than black', () {
      final colour = paint('label-place-city', 'text-color').toUpperCase();
      expect(colour, hex(AppMapColors.label));
      expect(colour, isNot('#000000'));
    });
  });

  group('3D buildings', () {
    test('are a real fill-extrusion, not a flat fill', () {
      expect(layer('building-3d')['type'], 'fill-extrusion');
    });

    test('take their height from the vector feature, ramped in by zoom', () {
      final height =
          (layer('building-3d')['paint'] as Map)['fill-extrusion-height'];
      final encoded = jsonEncode(height);
      // Zoom-interpolated so a city does not turn into towers when you pull
      // back, feature-driven so the towers that exist are the real ones.
      expect(encoded, contains('interpolate'));
      expect(encoded, contains('zoom'));
      expect(encoded, contains('render_height'));
    });

    test('use render_min_height for the base', () {
      expect(
        jsonEncode((layer('building-3d')['paint'] as Map)['fill-extrusion-base']),
        contains('render_min_height'),
      );
    });

    test('shade their sides through the vertical gradient', () {
      // The alternative is faking depth with Flutter shadows, which is the one
      // thing this layer exists to avoid.
      expect(
        (layer('building-3d')['paint'] as Map)['fill-extrusion-vertical-gradient'],
        isTrue,
      );
    });

    test('vary colour by height across the three building tones', () {
      final colour = jsonEncode(
        (layer('building-3d')['paint'] as Map)['fill-extrusion-color'],
      ).toUpperCase();
      for (final tone in [
        AppMapColors.buildingLow,
        AppMapColors.buildingMid,
        AppMapColors.buildingTall,
      ]) {
        final value =
            (tone.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
        expect(colour, contains(value.toUpperCase()));
      }
    });

    test('only extrude once the camera is close enough to matter', () {
      // Extruding a whole country's buildings is both unreadable and the
      // fastest way to melt a mid-range phone.
      expect(layer('building-3d')['minzoom'], greaterThanOrEqualTo(14));
      // ...and the flat fill has to hand over at the same point, or buildings
      // are drawn twice through the changeover.
      expect(layer('building-flat')['maxzoom'], greaterThan(14));
    });
  });

  group('MapStyleService', () {
    setUp(MapStyleService.resetCache);
    tearDownAll(MapStyleService.resetCache);

    test('resolves every placeholder', () async {
      final resolved = await MapStyleService().load();
      expect(resolved, isNot(contains('{{')));
      expect(resolved, isNot(contains(MapStyleService.tilesPlaceholder)));
      expect(resolved, isNot(contains(MapStyleService.glyphsPlaceholder)));
    });

    test('leaves the glyph template MapLibre fills in itself', () async {
      final resolved = await MapStyleService().load();
      // {fontstack} and {range} are MapLibre's, not ours — substituting them
      // would break every label on the map.
      expect(resolved, contains('{fontstack}'));
      expect(resolved, contains('{range}'));
    });

    test('still parses as JSON once substituted', () async {
      final resolved = await MapStyleService().load();
      final parsed = jsonDecode(resolved) as Map<String, dynamic>;
      expect(parsed['sources']['openmaptiles']['url'], startsWith('http'));
    });

    test('hands out the same instance rather than re-reading the bundle',
        () async {
      final service = MapStyleService();
      final first = await service.load();
      // Identity, not equality: a new string is what makes MapLibre tear the
      // style down and re-fetch every tile.
      expect(identical(first, await service.load()), isTrue);
      expect(identical(first, await MapStyleService().load()), isTrue);
    });
  });
}
