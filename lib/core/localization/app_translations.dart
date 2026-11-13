import 'translations/es.dart';
import 'translations/hi.dart';
import 'translations/bn.dart';
import 'translations/mr.dart';
import 'translations/te.dart';
import 'translations/ta.dart';

abstract final class AppTranslations {
  static const Map<String, Map<String, String>> _all = {
    'es': esTranslations,
    'hi': hiTranslations,
    'bn': bnTranslations,
    'mr': mrTranslations,
    'te': teTranslations,
    'ta': taTranslations,
  };

  /// Returns the translation for [key], or [fallback] (already-interpolated
  /// English) when the language or key is missing.
  ///
  /// Translated strings can't use Dart `$var` interpolation, so they use
  /// `{var}` placeholders which are filled from [params].
  static String get(
      String localeCode,
      String key,
      String fallback, [
        Map<String, Object?>? params,
      ]) {
    if (localeCode == 'en') return fallback;
    final value = _all[localeCode]?[key];
    if (value == null) return fallback;
    if (params == null || params.isEmpty) return value;
    var out = value;
    params.forEach((name, v) {
      out = out.replaceAll('{$name}', '${v ?? ''}');
    });
    return out;
  }
}