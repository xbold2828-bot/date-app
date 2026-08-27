import 'package:flutter/foundation.dart';
import '../logger/app_logger.dart';

extension SafeJsonParsing on Map<String, dynamic> {
  // ─────────────────────────────────────────
  // PRIVATE: prefix builder
  // ─────────────────────────────────────────
  String _p(String? tag) => tag != null ? '[$tag] ' : '';

  // ─────────────────────────────────────────
  // PRIVATE: key existence + value extractor (O(1) Optimized)
  // ─────────────────────────────────────────
  ({bool exists, dynamic value}) _get(String key, String? tag) {
    final value = this[key];

    // Happy path: O(1) single lookup
    if (value != null) return (exists: true, value: value);

    // Null or missing — distinguish with a 2nd lookup only when needed
    if (!containsKey(key)) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" missing in JSON → fallback will be used',
        );
      }
      return (exists: false, value: null);
    }

    // Key exists but value is explicitly null
    return (exists: true, value: null);
  }

  // ─────────────────────────────────────────
  // PRIVATE: null-exists guard (DRY helper)
  // ─────────────────────────────────────────
  void _logNull(String key, bool exists, dynamic fallback, String? tag) {
    if (kDebugMode && exists) {
      AppLogger.d('⚠️ ${_p(tag)}Key: "$key" is null → fallback: $fallback');
    }
  }

  // ─────────────────────────────────────────
  // BOOL
  // ─────────────────────────────────────────
  bool safeBool(String key, {bool fallback = false, String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseBool(value, key, exists, fallback, tag);
  }

  bool? safeBoolNullable(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseBool(value, key, exists, false, tag);
  }

  bool _parseBool(
    dynamic value,
    String key,
    bool exists,
    bool fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, fallback, tag);
      return fallback;
    }
    if (value is bool) return value;
    if (value is int) return value != 0;
    // FIX: also handle double (e.g. 1.0 / 0.0) as truthy/falsy
    if (value is double) return value != 0.0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (kDebugMode) {
      AppLogger.d(
        '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} value: "$value" → fallback: $fallback',
      );
    }
    return fallback;
  }

  // ─────────────────────────────────────────
  // STRING
  // ─────────────────────────────────────────
  String safeString(String key, {String fallback = '', String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseString(value, key, exists, fallback, tag);
  }

  String? safeStringNullable(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseString(value, key, exists, '', tag);
  }

  String _parseString(
    dynamic value,
    String key,
    bool exists,
    String fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, fallback, tag);
      return fallback;
    }
    if (value is String) return value;
    if (value is int || value is double || value is bool) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" type: ${value.runtimeType} value: "$value" → converting to String',
        );
      }
      return value.toString();
    }
    if (kDebugMode) {
      AppLogger.d(
        '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} value: "$value" → fallback: "$fallback"',
      );
    }
    return fallback;
  }

  // ─────────────────────────────────────────
  // INT
  // ─────────────────────────────────────────
  int safeInt(String key, {int fallback = 0, String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseInt(value, key, exists, fallback, tag);
  }

  int? safeIntNullable(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseInt(value, key, exists, 0, tag);
  }

  int _parseInt(
    dynamic value,
    String key,
    bool exists,
    int fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, fallback, tag);
      return fallback;
    }
    if (value is int) return value;
    if (value is double) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" is double: $value → converting to int',
        );
      }
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        if (kDebugMode) {
          AppLogger.d(
            '⚠️ ${_p(tag)}Key: "$key" is String: "$value" → parsed: $parsed',
          );
        }
        return parsed;
      }
    }
    if (value is bool) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" is bool: $value → converting to int',
        );
      }
      return value ? 1 : 0;
    }
    if (kDebugMode) {
      AppLogger.d(
        '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} value: "$value" → fallback: $fallback',
      );
    }
    return fallback;
  }

  // ─────────────────────────────────────────
  // DOUBLE
  // ─────────────────────────────────────────
  double safeDouble(String key, {double fallback = 0.0, String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseDouble(value, key, exists, fallback, tag);
  }

  double? safeDoubleNullable(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseDouble(value, key, exists, 0.0, tag);
  }

  double _parseDouble(
    dynamic value,
    String key,
    bool exists,
    double fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, fallback, tag);
      return fallback;
    }
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) {
        if (kDebugMode) {
          AppLogger.d(
            '⚠️ ${_p(tag)}Key: "$key" is String: "$value" → parsed: $parsed',
          );
        }
        return parsed;
      }
    }
    if (kDebugMode) {
      AppLogger.d(
        '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} value: "$value" → fallback: $fallback',
      );
    }
    return fallback;
  }

  // ─────────────────────────────────────────
  // NUM
  // ─────────────────────────────────────────
  num safeNum(String key, {num fallback = 0, String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseNum(value, key, exists, fallback, tag);
  }

  num? safeNumNullable(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseNum(value, key, exists, 0, tag);
  }

  num _parseNum(
    dynamic value,
    String key,
    bool exists,
    num fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, fallback, tag);
      return fallback;
    }
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) {
        if (kDebugMode) {
          AppLogger.d(
            '⚠️ ${_p(tag)}Key: "$key" is String: "$value" → parsed: $parsed',
          );
        }
        return parsed;
      }
    }
    if (kDebugMode) {
      AppLogger.d(
        '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} value: "$value" → fallback: $fallback',
      );
    }
    return fallback;
  }

  // ─────────────────────────────────────────
  // LIST
  // FIX: replaced lazy .cast<T>() with eager List<T>.from() so type
  // mismatches are caught immediately inside the try-catch, not later
  // during iteration in UI/business logic.
  // ─────────────────────────────────────────
  List<T> safeList<T>(
    String key, {
    List<T>? fallback,
    T Function(dynamic)? itemParser,
    String? tag,
  }) {
    final (:exists, :value) = _get(key, tag);
    return _parseList<T>(value, key, exists, fallback, itemParser, tag);
  }

  List<T>? safeListNullable<T>(
    String key, {
    T Function(dynamic)? itemParser,
    String? tag,
  }) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseList<T>(value, key, exists, null, itemParser, tag);
  }

  List<T> _parseList<T>(
    dynamic value,
    String key,
    bool exists,
    List<T>? fallback,
    T Function(dynamic)? itemParser,
    String? tag,
  ) {
    final effectiveFallback = fallback ?? <T>[];
    if (!exists || value == null) {
      _logNull(key, exists, '[]', tag);
      return effectiveFallback;
    }
    if (value is! List) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} → fallback: []',
        );
      }
      return effectiveFallback;
    }

    // With itemParser: parse item-by-item, skipping failures
    if (itemParser != null) {
      final result = <T>[];
      for (int i = 0; i < value.length; i++) {
        try {
          result.add(itemParser(value[i]));
        } catch (e) {
          if (kDebugMode) {
            AppLogger.d(
              '⚠️ ${_p(tag)}Key: "$key" index [$i] failed: $e → skipping item',
            );
          }
        }
      }
      return result;
    }

    // Without itemParser: use List.from() for eager evaluation (catches bad
    // casts immediately rather than deferring to the call site)
    try {
      return List<T>.from(value);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('⚠️ ${_p(tag)}Key: "$key" cast failed: $e → fallback: []');
      }
      return effectiveFallback;
    }
  }

  // ─────────────────────────────────────────
  // MAP
  // FIX: replaced lazy .cast<K,V>() with eager Map<K,V>.from() so type
  // mismatches surface here, not silently at the call site.
  // ─────────────────────────────────────────
  Map<K, V> safeMap<K, V>(String key, {Map<K, V>? fallback, String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseMap<K, V>(value, key, exists, fallback ?? <K, V>{}, tag);
  }

  Map<K, V>? safeMapNullable<K, V>(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    if (!exists || value == null) return null;
    return _parseMap<K, V>(value, key, exists, <K, V>{}, tag);
  }

  Map<K, V> _parseMap<K, V>(
    dynamic value,
    String key,
    bool exists,
    Map<K, V> fallback,
    String? tag,
  ) {
    if (!exists || value == null) {
      _logNull(key, exists, '{}', tag);
      return fallback;
    }
    if (value is! Map) {
      if (kDebugMode) {
        AppLogger.d(
          '⚠️ ${_p(tag)}Key: "$key" unexpected type: ${value.runtimeType} → fallback: {}',
        );
      }
      return fallback;
    }
    try {
      return Map<K, V>.from(value);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('⚠️ ${_p(tag)}Key: "$key" cast failed: $e → fallback: {}');
      }
      return fallback;
    }
  }

  // ─────────────────────────────────────────
  // NESTED OBJECT
  // FIX/DRY: now delegates to _parseMap<String, dynamic> to eliminate
  // the duplicate Map-handling logic that previously lived here.
  // ─────────────────────────────────────────
  Map<String, dynamic> safeObject(String key, {String? tag}) {
    final (:exists, :value) = _get(key, tag);
    return _parseMap<String, dynamic>(value, key, exists, {}, tag);
  }
}
