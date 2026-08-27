import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/env.dart';
import 'notification_channels.dart';

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
  // Nothing to persist yet. A data-only push is currently only used for silent
  // state sync, which the app re-reads from the API on resume anyway.
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
  // Private state
  // --------------------------------------------------------------------------

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static void Function(Map<String, dynamic>)? _tapCallback;
  static void Function(Map<String, dynamic>)? _dataMessageCallback;

  /// Called whenever FCM hands us a new token — on first fetch and on every
  /// rotation. This is the hook that keeps the backend's `device_tokens` row
  /// current; without it a rotated token is a device that silently stops
  /// receiving anything, with nothing anywhere reporting a problem.
  static void Function(String token)? _tokenRefreshCallback;

  static bool _coldStartHandled = false;
  static bool _refreshSubscribed = false;

  static String? _cachedToken;
  static Future<String?>? _tokenFuture;

  static NotificationPermissionState _permissionState =
      NotificationPermissionState.unknown;

  /// Public getter so UI code can check e.g.
  /// `if (NotificationHelper.permissionState == NotificationPermissionState.blocked) { showBanner(); }`
  static NotificationPermissionState get permissionState => _permissionState;

  /// The token currently held, without triggering a fetch. Null before the
  /// first successful `requestPermissionAndToken()`.
  static String? get cachedToken => _cachedToken;

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
  // PUBLIC API — STEP 2  (call once the user is signed in)
  // ==========================================================================

  /// Requests notification permission and fetches the FCM token.
  ///
  /// Resolves to a token string, or `null` if permission was denied/blocked
  /// or the token could not be fetched. NEVER throws — callers can safely
  /// `await` this without a try/catch.
  ///
  /// [onToken] is invoked with the first token AND with every rotation
  /// afterwards, so a caller that registers with the backend inside it stays
  /// correct for the life of the install rather than only at launch.
  static Future<String?> requestPermissionAndToken({
    void Function(String token)? onToken,
  }) async {
    if (onToken != null) _tokenRefreshCallback = onToken;

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

  /// Forgets this device's token, locally and at FCM.
  ///
  /// Call on sign-out, AFTER telling the backend to drop it — deleting it here
  /// first would leave the server holding a token it can no longer be told
  /// about, which is how one person ends up receiving another's notifications
  /// on a shared phone.
  ///
  /// Never throws: sign-out must complete whether or not FCM cooperates.
  static Future<void> deleteToken() async {
    _cachedToken = null;
    _tokenFuture = null;
    _permissionState = NotificationPermissionState.unknown;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] deleteToken failed (ignored): $e');
    }
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

    // iOS only. Left on, the OS draws its own banner for a foreground push AND
    // `onMessage` fires, so `_showLocalNotification` would draw a second one.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
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
        _tokenRefreshCallback?.call(token);
        _subscribeToTokenRefresh();
      }
      return token;
    });

    return _tokenFuture!;
  }

  /// Subscribes once, not once per fetch.
  ///
  /// `onTokenRefresh` is a broadcast stream, so re-subscribing on every call
  /// would leave a stack of live listeners all re-registering the same token
  /// with the backend on every rotation.
  static void _subscribeToTokenRefresh() {
    if (_refreshSubscribed) return;
    _refreshSubscribed = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
      _cachedToken = newToken;
      if (kDebugMode) debugPrint('[FCM] Token refreshed: $newToken');
      _tokenRefreshCallback?.call(newToken);
    });
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
            ? await FirebaseMessaging.instance.getToken(
                vapidKey: Env.firebaseVapidKey.isEmpty
                    ? null
                    : Env.firebaseVapidKey,
              )
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

    // Every channel the backend can send to, registered up front.
    //
    // Android silently routes a push whose `channel_id` it has never seen into
    // an unnamed low-importance channel: it arrives with no sound, no heads-up,
    // and nothing anywhere says why. Registering the whole set here is what
    // makes that class of bug impossible — and separate channels are also the
    // user's own control surface, so someone can keep messages loud while
    // silencing likes from the OS settings screen.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final channel in NotificationChannels.all) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            importance: channel.importance,
          ),
        );
      }
    }
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

    // The server echoes the channel it addressed into `data.channel_id`, so
    // the foreground copy lands in the same channel as the background one —
    // same sound, same importance, same OS-level switch. Falling back to the
    // general channel keeps an older server (or a console test push) audible
    // rather than silently mis-routed.
    final channel = NotificationChannels.byId(message.data['channel_id']);

    // Reusing the collapse key as the notification id is what makes twenty
    // messages from one conversation replace each other instead of stacking
    // twenty rows — matching what `collapse_key` already does for the
    // background case.
    final String? tag = message.data['collapse_key'] as String?;

    await _plugin.show(
      id: (tag ?? n.hashCode.toString()).hashCode,
      title: n.title,
      body: _stripHtml(n.body ?? ''),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: n.android?.smallIcon ?? '@mipmap/ic_launcher',
          importance: channel.importance,
          priority: Priority.high,
          playSound: true,
          tag: tag,
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
