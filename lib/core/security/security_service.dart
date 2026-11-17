// lib/core/security/security_service.dart
import 'dart:async';

import 'package:dating_app/core/security/security_risk.dart';
import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';
import 'package:safe_device/safe_device.dart';

import '../constants/app_constants.dart';
import '../logger/app_logger.dart';

abstract final class SecurityService {
  static bool debugForceBreach = false;

  static bool debugShowMessage = false;

  static bool debugForceSoftRisks = false;

  static const Duration _talsecSettleWindow = Duration(milliseconds: 1800);
  static const Duration _talsecRetrySettleWindow = Duration(milliseconds: 400);

  // Non-blocking risks: detected and reported, but never gate isSafe.
  static const Set<SecurityRisk> _softRisks = {
    SecurityRisk.deviceReinstalled,
    SecurityRisk.vpnActive,
    SecurityRisk.unsecureWifi,
    SecurityRisk.passcodeNotSet,
  };

  static bool _talsecStarted = false;
  static bool _listenerAttached = false;

  /// Risks reported by Talsec events (root, hooks, tamper...). Event based,
  /// so they stay until the app restarts.
  static final Set<SecurityRisk> _stickyRisks = <SecurityRisk>{};

  /// Risks that can be re-read at any time (dev mode, mock location...).
  /// Rebuilt from scratch on every check, so they clear once fixed.
  static final Set<SecurityRisk> _polledRisks = <SecurityRisk>{};

  /// Set when Talsec reports dev mode / ADB. Reset at the start of each check.
  static bool _devSignalSeen = false;

  /// Fires when Talsec reports a hard threat while the app is running.
  static final StreamController<void> _liveThreatController =
  StreamController<void>.broadcast();

  static Stream<void> get liveThreatStream => _liveThreatController.stream;

  static bool isHardRisk(SecurityRisk risk) => !_softRisks.contains(risk);

  static void _addSticky(SecurityRisk risk) {
    _stickyRisks.add(risk);
    if (isHardRisk(risk)) _liveThreatController.add(null);
  }

  static void _onDevSignal() {
    _devSignalSeen = true;
    _liveThreatController.add(null);
  }

  /// Filters a risk list down to the ones considered soft (non-blocking).
  static List<SecurityRisk> softRisksIn(List<SecurityRisk> risks) {
    return risks.where(_softRisks.contains).toList();
  }

  /// Human-readable label for a single security risk.
  static String riskLabel(SecurityRisk risk) {
    switch (risk) {
      case SecurityRisk.jailbrokenOrRooted:
        return 'Your device appears to be rooted or jailbroken.';
      case SecurityRisk.bootloaderUnlocked:
        return "Your device's bootloader is unlocked.";
      case SecurityRisk.debuggerAttached:
        return 'A debugger is attached to this app.';
      case SecurityRisk.devModeEnabled:
        return 'Developer options or USB debugging is enabled.';
      case SecurityRisk.hookDetected:
        return 'App hooking activity was detected.';
      case SecurityRisk.appTampered:
        return 'This app installation appears to be tampered with.';
      case SecurityRisk.appIntegrityFailed:
        return 'App integrity check failed.';
      case SecurityRisk.notRealDevice:
        return "You're running on an emulator or simulator.";
      case SecurityRisk.multiInstanceApp:
        return 'Multiple app instances or a cloned app were detected.';
      case SecurityRisk.screenCaptured:
        return 'Screen recording is active.';
      case SecurityRisk.passcodeNotSet:
        return 'Your device has no passcode or lock screen set.';
      case SecurityRisk.obfuscationIssues:
        return 'App code obfuscation could not be verified.';
      case SecurityRisk.mockLocation:
        return 'Mock location is enabled on this device.';
      case SecurityRisk.externalStorage:
        return 'The app is installed on external storage.';
      case SecurityRisk.screenshotTaken:
        return 'A screenshot was just taken.';
      case SecurityRisk.secureHardwareUnavailable:
        return 'Secure hardware storage is unavailable on this device.';
      case SecurityRisk.vpnActive:
        return 'A VPN connection is active.';
      case SecurityRisk.unsecureWifi:
        return "You're connected to an unsecured Wi-Fi network.";
      case SecurityRisk.timeSpoofed:
        return "Your device's system time appears to be spoofed.";
      case SecurityRisk.locationSpoofed:
        return 'Location spoofing was detected.';
      case SecurityRisk.automationDetected:
        return 'UI automation activity was detected.';
      case SecurityRisk.deviceReinstalled:
        return 'App data was recently restored or reinstalled.';
    }
  }

  static String buildWarningMessage(List<SecurityRisk> risks) {
    return risks.map(riskLabel).join(' ');
  }

  static List<SecurityRisk> _currentRisks() {
    final set = <SecurityRisk>{..._stickyRisks, ..._polledRisks};
    if (_devSignalSeen) set.add(SecurityRisk.devModeEnabled);
    return set.toList();
  }

  /// Launch-time check (used by the security gate).
  /// Safe to call repeatedly: polled risks are rebuilt on every call.
  static Future<SecurityCheckResult> evaluate() async {
    if (kDebugMode && debugForceBreach) {
      AppLogger.d('SecurityService: debugForceBreach forcing isSafe: false');
      return const SecurityCheckResult(
        isSafe: false,
        risks: SecurityRisk.values,
      );
    }

    if (kIsWeb) {
      return _evaluateWeb();
    }

    final bool isFirstRun = !_talsecStarted;
    if (isFirstRun) {
      _stickyRisks.clear();
    }
    _devSignalSeen = false;

    await _ensureTalsecStarted();
    await _refreshPolledRisks();

    await Future.delayed(
      isFirstRun ? _talsecSettleWindow : _talsecRetrySettleWindow,
    );

    final risks = _currentRisks();
    final hardRisks = risks.where(isHardRisk).toList();

    // Debug mode never blocks — risks are still reported so you can see
    // what's firing, but isSafe is forced true.
    if (kDebugMode) {
      if (!debugShowMessage) {
        return const SecurityCheckResult(isSafe: true, risks: []);
      }

      final debugRisks = debugForceSoftRisks
          ? <SecurityRisk>{...risks, ..._softRisks}.toList()
          : risks;

      if (debugForceSoftRisks) {
        AppLogger.d(
          'SecurityService: debugForceSoftRisks is true — injecting all '
              'soft risks for testing: $_softRisks',
        );
      }

      return SecurityCheckResult(isSafe: true, risks: debugRisks);
    }

    return SecurityCheckResult(isSafe: hardRisks.isEmpty, risks: risks);
  }

  /// Runtime check while the app is already running (app resume, live Talsec
  /// threat, or the "Check Again" button on the in-app breach page).
  ///
  /// [fresh] = true is used by "Check Again": it drops any stale dev-mode
  /// signal and waits briefly, so only the current device state counts.
  static Future<SecurityCheckResult> checkNow({bool fresh = false}) async {
    if (kIsWeb || kDebugMode) {
      return const SecurityCheckResult(isSafe: true, risks: []);
    }

    if (fresh) _devSignalSeen = false;

    await _refreshPolledRisks();

    if (fresh) await Future.delayed(_talsecRetrySettleWindow);

    final risks = _currentRisks();
    _devSignalSeen = false; // consumed

    final hardRisks = risks.where(isHardRisk).toList();
    return SecurityCheckResult(isSafe: hardRisks.isEmpty, risks: risks);
  }

  static Future<void> _ensureTalsecStarted() async {
    if (!_listenerAttached) {
      _attachListener();
      _listenerAttached = true;
    }

    if (_talsecStarted) return;

    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: AppConstants.packageName,
        signingCertHashes: [
          '2iJXGy1wuoSPkEpPOONk7qrtu5O2IktfYOt7EchFNpU=',
          // upload-keystore.jks release cert — if Play App Signing is
          // enabled, also add the Play signing key's SHA-256 hash here.
        ],
      ),
      iosConfig: IOSConfig(
        bundleIds: [AppConstants.packageName],
        teamId: 'YOUR_APPLE_TEAM_ID', // ⚠️ replace with real Team ID
      ),
      watcherMail: 'security@yourcompany.com',
      isProd: !kDebugMode,
    );

    try {
      await Talsec.instance.start(config);
      _talsecStarted = true;
    } catch (e) {
      AppLogger.d('Talsec start failed: $e');
    }
  }

  static void _attachListener() {
    Talsec.instance.attachListener(
      ThreatCallback(
        onPrivilegedAccess: () => _addSticky(SecurityRisk.jailbrokenOrRooted),
        onBootloader: () => _addSticky(SecurityRisk.bootloaderUnlocked),
        onDebug: () => _addSticky(SecurityRisk.debuggerAttached),
        // Dev mode / ADB are NOT sticky: they are re-read on every check so
        // "Check Again" works after the user turns them off.
        onDevMode: _onDevSignal,
        onADBEnabled: _onDevSignal,
        onHooks: () => _addSticky(SecurityRisk.hookDetected),
        onDeviceBinding: () => _addSticky(SecurityRisk.appTampered),
        // ⚠️ Temporarily disabled: re-enable once signingCertHashes (Android)
        // and teamId (iOS) are configured for the real release + Play App
        // Signing certs.
        // onAppIntegrity: () => _addSticky(SecurityRisk.appIntegrityFailed),
        onObfuscationIssues: () => _addSticky(SecurityRisk.obfuscationIssues),
        // Needs real Play Console / App Store Connect app ID to enforce.
        onUnofficialStore: () {},
        onSimulator: () => _addSticky(SecurityRisk.notRealDevice),
        onMultiInstance: () => _addSticky(SecurityRisk.multiInstanceApp),
        onScreenRecording: () => _addSticky(SecurityRisk.screenCaptured),
        // A screenshot is an event, not a device state: record it, but do not
        // trigger a live check for it.
        onScreenshot: () => _stickyRisks.add(SecurityRisk.screenshotTaken),
        onPasscode: () => _addSticky(SecurityRisk.passcodeNotSet),
        onSecureHardwareNotAvailable: () =>
            _addSticky(SecurityRisk.secureHardwareUnavailable),
        onSystemVPN: () => _addSticky(SecurityRisk.vpnActive),
        onUnsecureWiFi: () => _addSticky(SecurityRisk.unsecureWifi),
        onTimeSpoofing: () => _addSticky(SecurityRisk.timeSpoofed),
        onLocationSpoofing: () => _addSticky(SecurityRisk.locationSpoofed),
        onAutomation: () => _addSticky(SecurityRisk.automationDetected),
        onDeviceID: () => _addSticky(SecurityRisk.deviceReinstalled),
      ),
    );
  }

  /// Rebuilds [_polledRisks] from the current device state.
  static Future<void> _refreshPolledRisks() async {
    _polledRisks.clear();

    Future<void> check(Future<bool> Function() fn, SecurityRisk risk) async {
      try {
        if (await fn()) _polledRisks.add(risk);
      } catch (e) {
        AppLogger.d('SafeDevice check failed for $risk: $e');
      }
    }

    await check(() => SafeDevice.isMockLocation, SecurityRisk.mockLocation);
    await check(
          () => SafeDevice.isOnExternalStorage,
      SecurityRisk.externalStorage,
    );
    await check(
          () async => !(await SafeDevice.isRealDevice),
      SecurityRisk.notRealDevice,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await check(
            () => SafeDevice.isDevelopmentModeEnable,
        SecurityRisk.devModeEnabled,
      );
    }
  }

  static Future<SecurityCheckResult> _evaluateWeb() async {
    return const SecurityCheckResult(isSafe: true, risks: []);
  }
}
