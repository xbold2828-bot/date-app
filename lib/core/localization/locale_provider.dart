import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_string.dart';
import 'app_language.dart';

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(_preloaded ?? const Locale('en')) {
    if (_preloaded == null) {
      _restore();
    } else {
      AppString.setLocale(_preloaded!.languageCode);
    }
  }

  static const _key = 'selected_language_code';
  static Locale? _preloaded;

  /// Reads the saved choice before the first frame.
  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key) ?? 'en';
      _preloaded = Locale(code);
      AppString.setLocale(code);
    } catch (_) {
      _preloaded = const Locale('en');
      AppString.setLocale('en');
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key) ?? 'en';
      final locale = Locale(code);
      state = locale;
      AppString.setLocale(code);
    } catch (_) {
      state = const Locale('en');
      AppString.setLocale('en');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state.languageCode == language.code) return;
    AppString.setLocale(language.code); // first
    state = language.locale;            // then notify
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.code);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

