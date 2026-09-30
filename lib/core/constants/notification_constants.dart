/// Keys inside an FCM push's `data` map.
///
/// A wire contract with the backend (`notifications.constants.ts`), and one
/// that cannot be changed in lockstep: a build already on somebody's phone
/// keeps reading the old keys for as long as they decline to update. Treat
/// these as append-only.
abstract final class PushDataKeys {

  /// `normal` | `dataOnly`. The first thing the helper branches on.
  static const String fcmType = 'fcm_type';

  /// A [PushNotificationType] value.
  static const String type = 'type';

  /// A [PushAction] value — where the tap should land.
  static const String action = 'action';

  /// Android channel, echoed so a foreground push lands in the same channel as
  /// the background one.
  static const String channelId = 'channel_id';

  /// De-duplicates a socket event and a push describing the same thing.
  static const String notificationId = 'notification_id';

  static const String sentAt = 'sent_at';
  static const String conversationId = 'conversationId';
  static const String userId = 'userId';
  static const String messageId = 'messageId';
  static const String url = 'url';
}

/// `data.type` values.
abstract final class PushNotificationType {

  static const String chatMessage = 'chat.message';
  static const String matchNew = 'match.new';
  static const String likeReceived = 'like.received';
  static const String systemAnnouncement = 'system.announcement';
}

/// `data.action` values — what the tap handler should do.
abstract final class PushAction {

  static const String openConversation = 'open_conversation';
  static const String openMatches = 'open_matches';
  static const String openLikes = 'open_likes';
  static const String openProfile = 'open_profile';
  static const String openUrl = 'open_url';
  static const String none = 'none';
}