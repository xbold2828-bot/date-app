import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration.
///
/// Every value is **required** and comes from the `.env` file at the project
/// root — nothing is hardcoded here, so a missing or misspelled key fails
/// loudly on a config screen instead of silently pointing the app at the wrong
/// backend.
abstract final class Env {

  /// Supabase project URL. Must be the SAME project the backend verifies
  /// tokens against (see backend `.env` → `SUPABASE_URL`).
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Public anon key — safe to ship in the client, but kept out of the repo.
  /// Supabase Dashboard → Project Settings → API → Project API keys → `anon`.
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Backend REST base URL — already includes the `/api/v1` prefix.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  /// The **Web** OAuth client ID, used as `serverClientId` for native Google
  /// sign-in on Android/iOS.
  ///
  /// It must be the Web client, not the Android one. The Android client is
  /// matched implicitly by package name + signing SHA-1 and is never named in
  /// code; this value is what `requestIdToken` stamps as the `aud` of the ID
  /// token, and Supabase only accepts a token whose `aud` is in its Google
  /// provider's authorised client IDs. Passing an Android client ID here fails
  /// with `ApiException: 10` (DEVELOPER_ERROR).
  ///
  /// Not in [_required] — a web-only build never reaches the native path.
  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  /// Socket.io origin. The `/presence` and `/chat` namespaces are appended by
  /// the socket services, so this must NOT carry a path.
  static String get socketBaseUrl => dotenv.env['SOCKET_BASE_URL'] ?? '';

  // ── Explore map (optional) ────────────────────────────────────────────────
  //
  // These three are the only keys with defaults, and deliberately: the app has
  // to boot on a checkout that predates the map. The defaults point at
  // OpenFreeMap, which serves OpenMapTiles-schema vector tiles with no key and
  // no account. Point them at MapTiler / Stadia / your own tile server by
  // overriding them — anything speaking the same schema drops in, because the
  // style asset addresses source layers (`building`, `transportation`, …), not
  // a vendor.

  /// TileJSON URL for the vector tile source behind Explore.
  ///
  /// A literal `{key}` anywhere in the value is replaced with
  /// [mapTilesApiKey] at runtime, so a provider that wants its token in the
  /// query string never needs the token itself committed.
  static String get mapTilesUrl => dotenv.env['MAP_TILES_URL'] ?? 'https://tiles.openfreemap.org/planet';

  /// Font glyph endpoint for map labels. Must keep the `{fontstack}`/`{range}`
  /// placeholders — MapLibre fills those in itself.
  static String get mapGlyphsUrl => dotenv.env['MAP_GLYPHS_URL'] ?? 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

  /// Tile provider token, for providers that require one. Supplied in .env,
  /// never committed. Empty by default because the default provider needs no key.
  static String get mapTilesApiKey => dotenv.env['MAP_TILES_API_KEY'] ?? '';

  /// Substitutes [mapTilesApiKey] into a provider URL template.
  static String withMapKey(String url) =>
      mapTilesApiKey.isEmpty ? url : url.replaceAll('{key}', mapTilesApiKey);

  // ── Push notifications (optional) ─────────────────────────────────────────

  /// Web Push "Key pair" — Firebase Console → Project settings → Cloud
  /// Messaging → Web Push certificates.
  ///
  /// Required only on web, where `FirebaseMessaging.getToken()` will not
  /// return a token without it. Native builds ignore it entirely, which is why
  /// it is not in [_required]: a mobile-only build must not be blocked by a
  /// key it never uses.
  ///
  /// It is a *public* key — safe to ship — but it belongs to one Firebase
  /// project, so it lives here rather than in code, where the wrong project's
  /// key would silently produce tokens no cozune notification could ever reach.
  static String get firebaseVapidKey => dotenv.env['FIREBASE_VAPID_KEY'] ?? '';

  /// Keys that weren't supplied, so `main` can name them on the config screen.
  static List<String> get missingKeys {
    final requiredKeys = {
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_ANON_KEY': supabaseAnonKey,
      'API_BASE_URL': apiBaseUrl,
      'SOCKET_BASE_URL': socketBaseUrl,
    };

    return requiredKeys.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList(growable: false);
  }

  /// Whether the app has everything it needs to boot.
  static bool get isConfigured => missingKeys.isEmpty;
}