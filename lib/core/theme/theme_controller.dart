import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light / dark choice and remembers it between launches.
///
/// The app NEVER follows the phone's system theme. It starts in
/// [ThemeMode.light], and only the user changes it — with the dark-mode switch
/// in Settings. That choice is saved in SharedPreferences and restored on the
/// next launch.
///
/// Optional, to avoid a one-frame flash of light on launch for a user who saved
/// dark: call `await ThemeController.preload();` in `main()` before `runApp`
/// (after `WidgetsFlutterBinding.ensureInitialized()`). Without it the app still
/// works; the saved theme is simply applied a moment after the first frame.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(_preloaded ?? ThemeMode.light) {
    // If preload() already ran, the saved value is already applied.
    if (_preloaded == null) _restore();
  }

  static const _key = 'theme_mode';

  /// Filled by [preload]. Null means "not preloaded".
  static ThemeMode? _preloaded;

  /// Reads the saved choice before the first frame. See the class comment.
  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preloaded = _decode(prefs.getString(_key)) ?? ThemeMode.light;
    } catch (_) {
      _preloaded = ThemeMode.light;
    }
  }

  Future<void> _restore() async {
    // A missing or unreadable preference is not worth surfacing — the app just
    // stays light, which is what a first launch does.
    try {
      final prefs = await SharedPreferences.getInstance();
      state = _decode(prefs.getString(_key)) ?? ThemeMode.light;
    } catch (_) {
      // keep ThemeMode.light
    }
  }

  Future<void> set(ThemeMode mode) async {
    // The app only ever uses light or dark; "system" is not an option.
    final next = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    if (state == next) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next.name);
    } catch (_) {
      // The theme still changed for this session; only the memory is lost.
    }
  }

  /// What the 🌙 switch calls.
  Future<void> toggle({required bool dark}) =>
      set(dark ? ThemeMode.dark : ThemeMode.light);

  /// Only 'dark' means dark. Anything else — 'light', an old 'system' value
  /// saved by an earlier version, or nothing — is light.
  static ThemeMode? _decode(String? name) => switch (name) {
    'dark' => ThemeMode.dark,
    'light' || 'system' => ThemeMode.light,
    _ => null,
  };
}

final themeModeProvider =
StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

/// Whether the app is currently drawn dark — what the Settings switch shows.
/// The phone's system brightness is deliberately ignored.
bool isDarkMode(BuildContext context, ThemeMode mode) =>
    mode == ThemeMode.dark;