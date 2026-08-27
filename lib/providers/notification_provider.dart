import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger/app_logger.dart';
import '../core/notification/notification_helper.dart';
import '../data/models/notification_preferences_model.dart';
import '../data/repositories/notification_repository.dart';
import 'core_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

/// Where the FCM token gets tied to the signed-in account.
///
/// The two halves of push have to meet somewhere, and this is it: the helper
/// knows how to obtain a token, the repository knows how to tell the backend
/// about one, and neither knows when the user is signed in. That timing is the
/// whole job here — a token registered before the session exists is registered
/// against nobody, and one never registered at all is a device the server can
/// see no reason to notify.
class PushRegistrar {
  PushRegistrar(this._repository);

  final NotificationRepository _repository;

  /// The token this session registered, kept so sign-out can name it.
  String? _registered;

  /// Guards against the concurrent first calls that a rebuild can produce.
  Future<void>? _inFlight;

  /// Ask for permission, obtain a token, register it — and keep registering it
  /// on every rotation for the rest of the session.
  ///
  /// Call once the user is signed in AND the domain user exists server-side
  /// (i.e. after `GET /users/me` has returned), because registration is keyed
  /// to that user. Calling it earlier would either 401 or provision the user
  /// from the wrong place.
  ///
  /// Never throws. Notifications are an enhancement; a device that could not
  /// be registered must not stop somebody using the app, and the next launch
  /// tries again anyway.
  Future<void> start() {
    return _inFlight ??= _start().whenComplete(() => _inFlight = null);
  }

  Future<void> _start() async {
    try {
      final token = await NotificationHelper.requestPermissionAndToken(
        // Fires for the first token and for every rotation afterwards. Without
        // this the server keeps a token FCM has already retired, and the device
        // silently stops receiving anything — a failure with no error anywhere.
        onToken: _register,
      );

      if (token == null) {
        AppLogger.i(
          'Push: no token (permission '
          '${NotificationHelper.permissionState.name}) — notifications are off '
          'for this device until the user re-enables them in system settings.',
        );
      }
    } catch (e, s) {
      AppLogger.e('Push: registration failed', error: e, stackTrace: s);
    }
  }

  /// Fire-and-forget: `onTokenRefresh` is a stream callback with nobody to
  /// await it, and the caller of [start] is a widget build that must not block
  /// on a network round trip.
  void _register(String token) => unawaited(_registerNow(token));

  Future<void> _registerNow(String token) async {
    try {
      await _repository.registerDevice(token);
      _registered = token;
      AppLogger.d('Push: device registered');
    } catch (e) {
      AppLogger.w('Push: could not register device: $e');
    }
  }

  /// Detach this device from the account being signed out of.
  ///
  /// Order matters and is the reason this is not just `deleteToken()`: tell the
  /// server first, while the session is still valid enough to authorise the
  /// call, and only then discard the token locally. Doing it the other way
  /// leaves the server holding a token it can never be told about — which is
  /// how the next person to sign in on a shared phone starts receiving the
  /// previous account's messages.
  ///
  /// Never throws: signing out must succeed whether or not this does.
  Future<void> stop() async {
    final token = _registered ?? NotificationHelper.cachedToken;
    _registered = null;

    if (token != null) {
      try {
        await _repository.unregisterDevice(token);
      } catch (e) {
        AppLogger.w('Push: could not unregister device: $e');
      }
    }

    await NotificationHelper.deleteToken();
  }
}

/// One registrar per app session.
///
/// Deliberately not autoDispose — it holds the token this session registered,
/// which sign-out needs, and a disposal in between would lose it.
final pushRegistrarProvider = Provider<PushRegistrar>(
  (ref) => PushRegistrar(ref.watch(notificationRepositoryProvider)),
);

/// My notification settings, for a settings screen.
class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() =>
      ref.watch(notificationRepositoryProvider).preferences();

  /// Applies a change optimistically, then reconciles with what the server
  /// stored.
  ///
  /// Named `save` rather than `update` because `AsyncNotifier` already defines
  /// an `update` with an incompatible signature — overriding it by accident is
  /// a compile error, and shadowing it would be worse.
  ///
  /// A settings toggle that waits on a round trip before moving reads as
  /// broken, and the failure path matters more than usual here: if the write
  /// fails, the switch must snap back rather than sit there showing a setting
  /// the server never accepted.
  Future<void> save({
    bool? messages,
    bool? matches,
    bool? likes,
    bool? announcements,
    QuietHours? quietHours,
  }) async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(
          messages: messages,
          matches: matches,
          likes: likes,
          announcements: announcements,
          quietHours: quietHours,
        ),
      );
    }

    try {
      final saved = await ref.read(notificationRepositoryProvider).updatePreferences(
            messages: messages,
            matches: matches,
            likes: likes,
            announcements: announcements,
            quietHours: quietHours,
          );
      state = AsyncData(saved);
    } catch (e, s) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(e, s);
      }
      rethrow;
    }
  }
}

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);
