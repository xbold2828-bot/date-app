import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One Android notification channel.
class AppNotificationChannel {
  const AppNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
    this.importance = Importance.high,
  });

  /// Must match the backend exactly — see `notifications.constants.ts`.
  final String id;

  /// What the user sees in Android's per-app notification settings.
  final String name;
  final String description;
  final Importance importance;
}

/// The notification channels cozune registers, and the wire contract behind
/// them.
///
/// **These ids are shared with the backend.** A channel id the device has never
/// registered is not an error — it is worse: Android routes the push into an
/// unnamed low-importance channel where it arrives silently, and nothing
/// anywhere reports a problem. (That was already the state of this app: the old
/// client-side sender addressed `marksmann_high_importance` while the helper
/// registered `trueheal_high_importance`, both inherited from other products,
/// so neither one ever matched.)
///
/// Ids are also permanent in a way most constants are not: Android remembers a
/// channel's settings under its id forever, and a channel the user has silenced
/// stays silenced even if the app deletes and recreates it. Renaming one
/// therefore resets every user's choice — so change [name] and [description]
/// freely, and treat [id] as immutable.
abstract final class NotificationChannels {
  /// Chat. The one people actually open, so it stays at max importance —
  /// heads-up banner, sound, the lot.
  static const messages = AppNotificationChannel(
    id: 'cozune_messages',
    name: 'Messages',
    description: 'Someone sent you a message.',
    importance: Importance.max,
  );

  /// Matches. The best moment the product has; worth interrupting for.
  static const matches = AppNotificationChannel(
    id: 'cozune_matches',
    name: 'Matches',
    description: 'Someone liked you back.',
    importance: Importance.max,
  );

  /// Likes. Deliberately quieter: these are throttled server-side and are an
  /// invitation to come back rather than something to answer right now.
  static const likes = AppNotificationChannel(
    id: 'cozune_likes',
    name: 'Likes',
    description: 'Someone new likes you.',
    importance: Importance.defaultImportance,
  );

  /// Announcements from cozune. The one people switch off first, and the one
  /// that should never buzz.
  static const announcements = AppNotificationChannel(
    id: 'cozune_announcements',
    name: 'Announcements',
    description: 'News and updates from cozune.',
    importance: Importance.low,
  );

  static const List<AppNotificationChannel> all = [
    messages,
    matches,
    likes,
    announcements,
  ];

  /// The channel with this id, or [announcements] when the id is missing or
  /// unrecognised.
  ///
  /// Falling back rather than throwing keeps a push from a newer server — or
  /// from the Firebase console, which sends no `channel_id` at all — visible
  /// instead of silently mis-routed.
  static AppNotificationChannel byId(Object? id) {
    for (final channel in all) {
      if (channel.id == id) return channel;
    }
    return announcements;
  }
}
