import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// =============================================================================
// BACKGROUND HANDLER (Android/iOS only — ignored on web)
// Must be top-level. Register in main() BEFORE runApp:
//   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
// =============================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final String fcmType = message.data['fcm_type'] ?? 'normal';

  if (kDebugMode) {
    debugPrint('[FCM][BG] type=$fcmType');
    debugPrint('[FCM][BG] title=${message.notification?.title}');
    debugPrint('[FCM][BG] data=${message.data}');
  }

  if (fcmType == 'dataOnly') {
    _handleDataOnlyBackground(message.data);
  }
}

void _handleDataOnlyBackground(Map<String, dynamic> data) {
  final String action = data['action'] ?? '';
  if (kDebugMode) debugPrint('[FCM][BG][dataOnly] action=$action');
  // TODO: write to local DB here if needed
}

// =============================================================================
// PERMISSION STATE (exposed so the app / UI can react, e.g. show a banner
// telling the user how to unblock notifications from browser settings)
// =============================================================================

enum NotificationPermissionState {
  /// Not yet requested / unknown.
  unknown,

  /// Granted — token fetch should succeed.
  granted,

  /// User denied but can still be re-prompted (native denied, or
  /// browser "default"/not-yet-decided in some cases).
  denied,

  /// Permanently blocked at the OS/browser level. getToken() will always
  /// throw `permission-blocked`. Only the user can undo this, via
  /// browser/site settings.
  blocked,
}

// =============================================================================
// NOTIFICATION HELPER
// =============================================================================

abstract final class NotificationHelper {
  // --------------------------------------------------------------------------
  // Constants
  // --------------------------------------------------------------------------

  static const String _channelId = 'trueheal_high_importance';
  static const String _channelName = 'TrueHeal Notifications';
  static const String _channelDesc = 'Important notifications from TrueHeal.';

  /// REQUIRED for FirebaseMessaging.getToken() to work on web.
  /// Firebase Console → Project settings → Cloud Messaging → Web Push
  /// certificates → "Key pair".
  static const String _vapidKey =
      'BCSDn6R866ZmevxEcZNYwt5PrzEy4eSn6H8_pJxLQKp02QneSx67I7nMgUGt0rT9f7-ckrIV6taKzNWrYHB1u0s';

  // --------------------------------------------------------------------------
  // Private state
  // --------------------------------------------------------------------------

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static void Function(Map<String, dynamic>)? _tapCallback;
  static void Function(Map<String, dynamic>)? _dataMessageCallback;

  static bool _coldStartHandled = false;

  static String? _cachedToken;
  static Future<String?>? _tokenFuture;

  static NotificationPermissionState _permissionState =
      NotificationPermissionState.unknown;

  /// Public getter so UI code can check e.g.
  /// `if (NotificationHelper.permissionState == NotificationPermissionState.blocked) { showBanner(); }`
  static NotificationPermissionState get permissionState => _permissionState;

  // ==========================================================================
  // PUBLIC API — STEP 1  (call in main(), before runApp)
  // ==========================================================================

  static Future<void> initCore({
    void Function(Map<String, dynamic>)? onNotificationTap,
    void Function(Map<String, dynamic>)? onDataMessage,
  }) async {
    _tapCallback = onNotificationTap;
    _dataMessageCallback = onDataMessage;

    // flutter_local_notifications is not supported on web — skip entirely.
    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    _listenFcm(
      onNotificationTap: onNotificationTap,
      onDataMessage: onDataMessage,
    );
    await _checkColdStart(onNotificationTap: onNotificationTap);

    if (kDebugMode) {
      debugPrint('[NotificationHelper] Core initialised ✅ (web=$kIsWeb)');
    }
  }

  // ==========================================================================
  // PUBLIC API — STEP 2  (call in SplashController BEFORE any early return)
  // ==========================================================================

  /// Requests notification permission and fetches the FCM token.
  ///
  /// Resolves to a token string, or `null` if permission was denied/blocked
  /// or the token could not be fetched. NEVER throws — callers can safely
  /// `await` this without a try/catch.
  static Future<String?> requestPermissionAndToken() async {
    final NotificationSettings settings = await _requestPermissions();

    // Fast-fail: if the browser/OS has already blocked/denied permission,
    // don't bother calling getToken() at all — it would just throw
    // permission-blocked repeatedly. Save the round trip.
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _permissionState = NotificationPermissionState.denied;
      if (kDebugMode) {
        debugPrint(
          '[NotificationHelper] Permission denied — skipping token fetch. '
          'User can re-enable via browser/OS notification settings.',
        );
      }
      return null;
    }

    final String? token = await _fetchAndCacheToken();

    if (kDebugMode) {
      debugPrint(
        '[NotificationHelper] Permission requested & token fetch done '
        '(state=$_permissionState, token=$token)',
      );
    }
    return token;
  }

  // ==========================================================================
  // PRIVATE — permissions
  // ==========================================================================

  static Future<NotificationSettings> _requestPermissions() async {
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    if (kDebugMode) {
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    }

    return settings;
  }

  // ==========================================================================
  // PRIVATE / PUBLIC — FCM token
  // ==========================================================================

  static Future<String?> _fetchAndCacheToken() {
    if (_tokenFuture != null) return _tokenFuture!;

    _tokenFuture = _fetchTokenWithRetry().then((token) {
      _cachedToken = token;
      _tokenFuture = null;

      if (token != null) {
        _permissionState = NotificationPermissionState.granted;
        FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
          _cachedToken = newToken;
          if (kDebugMode) debugPrint('[FCM] Token refreshed: $newToken');
          // TODO: POST newToken to your backend
        });
      }
      return token;
    });

    return _tokenFuture!;
  }

  /// Retries getToken() for transient failures (e.g. iOS APNs not ready
  /// yet). Stops immediately — no retry — for `permission-blocked` /
  /// `permission-denied`, since those can never succeed by retrying; only
  /// the user changing browser/OS settings can fix them.
  static Future<String?> _fetchTokenWithRetry({
    int maxAttempts = 5,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Platform.isIOS/isAndroid THROW on web — must gate behind !kIsWeb.
        if (!kIsWeb && Platform.isIOS) {
          final String? apns = await FirebaseMessaging.instance.getAPNSToken();
          if (kDebugMode) {
            debugPrint('[FCM] APNs token (attempt $attempt): $apns');
          }
          if (apns == null) {
            await Future.delayed(delay);
            continue;
          }
        }

        final String? token = kIsWeb
            ? await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey)
            : await FirebaseMessaging.instance.getToken();

        if (kDebugMode) {
          debugPrint('[FCM] Device token (attempt $attempt): $token');
        }

        if (token != null) return token;
      } on FirebaseException catch (e) {
        final bool isBlocked =
            e.code == 'permission-blocked' || e.code == 'permission-denied';

        if (kDebugMode) {
          debugPrint(
            '[FCM] token fetch attempt $attempt error: ${e.code} — ${e.message}',
          );
        }

        if (isBlocked) {
          _permissionState = NotificationPermissionState.blocked;
          if (kDebugMode) {
            debugPrint(
              '[FCM] Permission is blocked at the browser/OS level. '
              'Aborting retries — the user must re-enable notifications '
              'manually (site settings / OS settings). Not a code bug.',
            );
          }
          return null; // stop immediately, retrying is pointless
        }
        // Any other FirebaseException: fall through and retry.
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[FCM] token fetch attempt $attempt error: $e');
        }
      }
      await Future.delayed(delay);
    }
    return null;
  }

  /// Returns the FCM token string, using the cache when available.
  /// Returns `null` (never throws) if permission is blocked/denied or the
  /// token could not be fetched. Callers must handle `null` — e.g.
  /// `await NotificationHelper.getDeviceToken() ?? ''` before sending to
  /// an API that requires a String field.
  static Future<String?> getDeviceToken() async {
    if (_cachedToken != null) return _cachedToken;

    // If we already know permission is blocked, don't even try — avoids
    // spamming the same permission-blocked exception on every login call.
    if (_permissionState == NotificationPermissionState.blocked) {
      return null;
    }

    return _fetchAndCacheToken();
  }

  // ==========================================================================
  // PRIVATE — local notifications setup (Android/iOS/desktop only)
  // ==========================================================================

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
          ),
        );
  }

  @pragma('vm:entry-point')
  static void _onLocalNotifTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final Map<String, dynamic> data =
          jsonDecode(payload) as Map<String, dynamic>;
      _tapCallback?.call(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[LocalNotif] payload decode error: $e');
    }
  }

  // ==========================================================================
  // PRIVATE — show local notification (foreground only, native platforms)
  // ==========================================================================

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    // No flutter_local_notifications support on web. Route foreground
    // messages to onDataMessage instead so the app can render its own
    // in-app banner/snackbar.
    if (kIsWeb) {
      _dataMessageCallback?.call(message.data);
      return;
    }

    final RemoteNotification? n = message.notification;
    if (n == null) return;

    await _plugin.show(
      id: n.hashCode,
      title: n.title,
      body: _stripHtml(n.body ?? ''),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          icon: n.android?.smallIcon ?? '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ==========================================================================
  // PRIVATE — FCM listeners
  // ==========================================================================

  static void _listenFcm({
    void Function(Map<String, dynamic>)? onNotificationTap,
    void Function(Map<String, dynamic>)? onDataMessage,
  }) {
    // ── FOREGROUND ──────────────────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String fcmType = message.data['fcm_type'] ?? 'normal';

      if (kDebugMode) {
        debugPrint(
          '[FCM][FG] type=$fcmType | title=${message.notification?.title}',
        );
      }

      if (fcmType == 'dataOnly') {
        onDataMessage?.call(message.data);
      } else {
        _showLocalNotification(message);
      }
    });

    // ── BACKGROUND TAP (works on web too — user clicks the browser push) ──
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String fcmType = message.data['fcm_type'] ?? 'normal';

      if (kDebugMode) {
        debugPrint('[FCM][BG→FG tap] type=$fcmType | data=${message.data}');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (fcmType == 'dataOnly') {
          onDataMessage?.call(message.data);
        } else {
          _navigate(message.data, onNotificationTap);
        }
      });
    });
  }

  // ==========================================================================
  // PRIVATE — cold start
  // ==========================================================================

  static Future<void> _checkColdStart({
    void Function(Map<String, dynamic>)? onNotificationTap,
  }) async {
    if (_coldStartHandled) return;

    final RemoteMessage? initial = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initial == null) return;

    _coldStartHandled = true;

    final String fcmType = initial.data['fcm_type'] ?? 'normal';
    if (kDebugMode) {
      debugPrint('[FCM][COLD START] type=$fcmType | data=${initial.data}');
    }

    if (fcmType == 'normal') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        _navigate(initial.data, onNotificationTap);
      });
    }
  }

  // ==========================================================================
  // PRIVATE — navigation
  // ==========================================================================

  static void _navigate(
    Map<String, dynamic> rawData,
    void Function(Map<String, dynamic>)? onNotificationTap,
  ) {
    final Map<String, dynamic> data = _unwrapNestedData(rawData);
    if (onNotificationTap != null) {
      onNotificationTap(data);
    } else if (kDebugMode) {
      debugPrint('[NotificationHelper] onNotificationTap callback not set.');
    }
  }

  // ==========================================================================
  // PRIVATE — utilities
  // ==========================================================================

  static Map<String, dynamic> _unwrapNestedData(Map<String, dynamic> raw) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(raw);
    if (copy['data'] is String) {
      try {
        final dynamic decoded = jsonDecode(copy['data'] as String);
        if (decoded is Map<String, dynamic>) {
          copy
            ..remove('data')
            ..addAll(decoded);
        }
      } catch (_) {}
    }
    return copy;
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
