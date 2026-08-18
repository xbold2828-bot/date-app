import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light / dark choice and remembers it between launches.
///
/// The default is [ThemeMode.system], so a phone already in dark mode opens the
/// app dark without anyone touching the switch. Once the user flips it by hand
/// the choice is explicit and sticks.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'theme_mode';

  Future<void> _restore() async {
    // A missing or unreadable preference is not worth surfacing — the app just
    // follows the system, which is what a first launch does anyway.
    try {
      final prefs = await SharedPreferences.getInstance();
      state = _decode(prefs.getString(_key)) ?? ThemeMode.system;
    } catch (_) {
      // keep ThemeMode.system
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // The theme still changed for this session; only the memory is lost.
    }
  }

  /// What the 🌙 switch calls. Flipping it is always an explicit choice, so it
  /// lands on [ThemeMode.light] or [ThemeMode.dark] and stops following the
  /// system.
  Future<void> toggle({required bool dark}) =>
      set(dark ? ThemeMode.dark : ThemeMode.light);

  static ThemeMode? _decode(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

/// Whether the app is *currently* being drawn dark, with [ThemeMode.system]
/// resolved against the platform. This is what the switch shows, so that a
/// user on system-dark sees the switch already on.
bool isDarkMode(BuildContext context, ThemeMode mode) => switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
