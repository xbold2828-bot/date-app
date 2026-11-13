import 'package:flutter/material.dart';

enum AppLanguage {
  english(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    flag: '🇺🇸',
  ),
  spanish(
    code: 'es',
    englishName: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
  ),
  hindi(
    code: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
  ),
  bengali(
    code: 'bn',
    englishName: 'Bengali',
    nativeName: 'বাংলা',
    flag: '🇮🇳',
  ),
  marathi(
    code: 'mr',
    englishName: 'Marathi',
    nativeName: 'मराठी',
    flag: '🇮🇳',
  ),
  telugu(
    code: 'te',
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
    flag: '🇮🇳',
  ),
  tamil(
    code: 'ta',
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
    flag: '🇮🇳',
  );

  final String code;
  final String englishName;
  final String nativeName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
  });

  Locale get locale => Locale(code);

  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((l) => l.locale).toList();

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (l) => l.code == code.toLowerCase().trim(),
      orElse: () => AppLanguage.english,
    );
  }
}

