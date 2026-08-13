import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/env.dart';
import '../../core/errors/app_exceptions.dart';

/// Builds the MapLibre style document Explore renders.
///
/// The style itself lives in `assets/map/explore_style.json` — a real style
/// document, editable and diffable, rather than a megabyte of escaped JSON
/// wedged into a Dart string. Two things in it cannot be known until run time,
/// so they are placeholders the asset carries and this fills in:
///
///   `{{TILES_URL}}`  → [Env.mapTilesUrl], with any `{key}` resolved
///   `{{GLYPHS_URL}}` → [Env.mapGlyphsUrl], likewise
///
/// The result is cached for the process. A style string is ~14 KB and the
/// Explore tab is rebuilt every time it is selected; re-reading the bundle and
/// re-substituting on each of those would be pure waste, and handing MapLibre a
/// *new* string is what makes it tear down and re-fetch every vector tile.
class MapStyleService {
  MapStyleService();

  static const String assetPath = 'assets/map/explore_style.json';

  /// Placeholders the asset declares. Named here so a rename in the asset that
  /// isn't mirrored here fails the test rather than shipping a map whose
  /// source URL is the literal string `{{TILES_URL}}`.
  static const String tilesPlaceholder = '{{TILES_URL}}';
  static const String glyphsPlaceholder = '{{GLYPHS_URL}}';

  static String? _cached;

  /// The finished style document.
  ///
  /// Throws [MapStyleException] if the asset is missing or still carries an
  /// unresolved placeholder, so the screen can show its "map couldn't load"
  /// state instead of handing MapLibre something it will fail on silently.
  Future<String> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      throw const MapStyleException(
        'The map style is missing from this build.',
      );
    }

    final style = raw
        .replaceAll(tilesPlaceholder, Env.withMapKey(Env.mapTilesUrl))
        .replaceAll(glyphsPlaceholder, Env.withMapKey(Env.mapGlyphsUrl));

    if (style.contains('{{')) {
      throw const MapStyleException(
        'The map style has a placeholder nothing filled in.',
      );
    }

    return _cached = style;
  }

  /// Drops the cached document. Only tests need this — the substituted values
  /// are compile-time constants, so nothing changes them while the app runs.
  static void resetCache() => _cached = null;
}

/// The style document could not be produced. Distinct from a tile or network
/// failure: this one is never worth retrying, because nothing about it changes
/// between attempts.
class MapStyleException extends AppException {
  const MapStyleException(super.message) : super(error: 'MapStyleUnavailable');
}
