import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract final class AppLogger {

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      noBoxingByDefault: true,
    ),
  );

  /// VERBOSE: Very detailed logs (rare)
  static void v(String message) {
    if (kDebugMode) {
      _logger.t(message);
    }
  }

  /// DEBUG: Development debugging
  static void d(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  /// INFO: Normal app flow
  static void i(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  /// SUCCESS: Positive result
  static void success(String message) {
    if (kDebugMode) {
      _logger.i('✅ SUCCESS: $message');
    }
  }

  /// WARNING: Potential issue
  static void w(String message) {
    if (kDebugMode) {
      _logger.w('⚠️ WARNING: $message');
    }
  }

  /// ERROR: Something failed
  static void e(
      String message, {
        Object? error,
        StackTrace? stackTrace,
      }) {
    if (kDebugMode) {
      _logger.e(
        '❌ ERROR: $message',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // FirebaseCrashlytics.instance.recordError(
      //   error ?? message,
      //   stackTrace,
      //   reason: message,
      //   fatal: false,
      // );
    }
  }

  /// FATAL: App-breaking error
  static void fatal(
      String message, {
        Object? error,
        StackTrace? stackTrace,
      }) {
    if (kDebugMode) {
      _logger.f(
        '🔥 FATAL: $message',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // FirebaseCrashlytics.instance.recordError(
      //   error ?? message,
      //   stackTrace,
      //   reason: message,
      //   fatal: true,
      // );
    }
  }
}
