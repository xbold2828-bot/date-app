import 'package:package_info_plus/package_info_plus.dart';

/// Global, app-wide package/build info.
///
/// Call [AppInfo.init] once in main() before runApp(). After that,
/// every screen can read [AppInfo.version], [AppInfo.buildNumber], etc.
/// synchronously — no FutureBuilder, no per-screen platform calls.
abstract final class AppInfo {
  static PackageInfo? _packageInfo;

  static bool get isInitialized => _packageInfo != null;

  /// Fetches and caches package info. Safe to call once at startup.
  /// If it fails (rare), fields fall back to empty strings rather than
  /// throwing, so app startup is never blocked by this.
  static Future<void> init() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }
  }

  static String get appName => _packageInfo?.appName ?? '';

  static String get packageName => _packageInfo?.packageName ?? '';

  static String get version => _packageInfo?.version ?? '';

  static String get buildNumber => _packageInfo?.buildNumber ?? '';

  static String? get installerStore => _packageInfo?.installerStore;

  /// Convenience label, e.g. "PROD - v 9.4.0 (630)"
  /// Returns '' if info isn't available yet, so UI can hide it gracefully.
  static String get versionLabel {
    if (!isInitialized || version.isEmpty) return '';
    return 'PROD - v $version ($buildNumber)';
  }
}
