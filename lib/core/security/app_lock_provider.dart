
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';

/// Result of turning the lock on or off from Settings.
enum AppLockChange { done, unsupported, failed }

@immutable
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  /// The user's setting (persisted).
  final bool enabled;

  /// Runtime state: true while the lock screen is covering the app.
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
  );
}

/// Optional biometric / device-credential app lock.
///
/// Call `await AppLockController.preload();` in `main()` before `runApp` so a
/// cold start with the lock enabled begins locked, with no unlocked frame.
class AppLockController extends Notifier<AppLockState> {
  static const _key = 'app_lock_enabled';

  /// Re-lock when the app was in the background longer than this.
  static const relockAfter = Duration(seconds: 20);

  static bool _preloadedEnabled = false;

  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preloadedEnabled = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Unreadable preference: fail open rather than lock the user out.
      _preloadedEnabled = false;
    }
  }

  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _pausedAt;
  bool _authenticating = false;

  @override
  AppLockState build() {
    // If the user removed their device PIN/biometrics since enabling the lock,
    // they could never get past the lock screen. Drop the lock instead.
    if (_preloadedEnabled) Future.microtask(_dropIfUnsupported);
    return AppLockState(enabled: _preloadedEnabled, locked: _preloadedEnabled);
  }

  Future<bool> _supported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> _dropIfUnsupported() async {
    if (await _supported()) return;
    AppLogger.w('App lock disabled: device no longer supports it');
    await _persist(false);
    state = const AppLockState(enabled: false, locked: false);
  }

  Future<void> _persist(bool value) async {
    _preloadedEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      AppLogger.d('App lock: could not persist setting: $e');
    }
  }

  /// One system prompt at a time. Device PIN/pattern is the fallback.
  Future<bool> _authenticate(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      AppLogger.d('App lock: authentication error: $e');
      return false;
    } finally {
      _authenticating = false;
      // The prompt itself pauses/resumes the app; never count that as
      // "time in the background".
      _pausedAt = null;
    }
  }

  /// Called by the lock screen.
  Future<void> unlock(String reason) async {
    if (!state.locked) return;
    if (await _authenticate(reason)) {
      state = state.copyWith(locked: false);
    }
  }

  /// Called by the Settings switch. Requires a successful authentication in
  /// both directions, so the lock can't be switched off by whoever is holding
  /// the phone.
  Future<AppLockChange> setEnabled(bool on, {required String reason}) async {
    if (on == state.enabled) return AppLockChange.done;

    final supported = await _supported();
    if (on && !supported) return AppLockChange.unsupported;
    // Turning off on a device that lost its screen lock can't be authenticated.
    if (supported && !await _authenticate(reason)) return AppLockChange.failed;

    await _persist(on);
    state = AppLockState(enabled: on, locked: false);
    return AppLockChange.done;
  }

  /// Sign out / delete account: the lock belongs to this session, so the next
  /// account on the device doesn't inherit it.
  Future<void> reset() async {
    _pausedAt = null;
    await _persist(false);
    state = const AppLockState(enabled: false, locked: false);
  }

  void onPaused() {
    if (!state.enabled || _authenticating) return;
    _pausedAt ??= DateTime.now();
  }

  void onResumed() {
    final at = _pausedAt;
    _pausedAt = null;
    if (!state.enabled || _authenticating || at == null) return;
    if (DateTime.now().difference(at) > relockAfter) {
      state = state.copyWith(locked: true);
    }
  }
}

final appLockProvider =
NotifierProvider<AppLockController, AppLockState>(AppLockController.new);