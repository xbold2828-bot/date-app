/// Environment configuration.
///
/// Every value is **required** and comes from the `.env` file at the project
/// root — nothing is hardcoded here, so a missing or misspelled key fails
/// loudly on a config screen instead of silently pointing the app at the wrong
/// backend. Copy `.env.example` → `.env`, fill it in, then pass it at run time:
///
/// ```
/// flutter run -d chrome --web-port=3000 --dart-define-from-file=.env
/// flutter run --dart-define-from-file=.env
/// flutter build web --dart-define-from-file=.env
/// ```
///
/// Individual keys can still be overridden with `--dart-define=KEY=value`,
/// which wins over the file.
class Env {
  Env._();

  /// Supabase project URL. Must be the SAME project the backend verifies
  /// tokens against (see backend `.env` → `SUPABASE_URL`).
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Public anon key — safe to ship in the client, but kept out of the repo.
  /// Supabase Dashboard → Project Settings → API → Project API keys → `anon`.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Backend REST base URL — already includes the `/api/v1` prefix.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Socket.io origin. The `/presence` and `/chat` namespaces are appended by
  /// the socket services, so this must NOT carry a path.
  static const String socketBaseUrl =
      String.fromEnvironment('SOCKET_BASE_URL');

  /// Every key the app needs, paired with whatever was supplied for it.
  static const Map<String, String> _required = {
    'SUPABASE_URL': supabaseUrl,
    'SUPABASE_ANON_KEY': supabaseAnonKey,
    'API_BASE_URL': apiBaseUrl,
    'SOCKET_BASE_URL': socketBaseUrl,
  };

  /// Keys that weren't supplied, so `main` can name them on the config screen.
  static List<String> get missingKeys => _required.entries
      .where((e) => e.value.trim().isEmpty)
      .map((e) => e.key)
      .toList(growable: false);

  /// Whether the app has everything it needs to boot.
  static bool get isConfigured => missingKeys.isEmpty;
}
