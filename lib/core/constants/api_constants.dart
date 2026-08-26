import 'env.dart';

/// REST endpoint paths and client timeouts.
///
/// All paths are relative to [baseUrl] (which already contains `/api/v1`).
/// Success responses are wrapped by the backend in `{ success, data, ... }`;
/// the [EnvelopeInterceptor] unwraps that so callers receive `data` directly.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = Env.apiBaseUrl;
  static const String socketUrl = Env.socketBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ── Health / Tags (public) ──────────────────────────────────────────────
  static const String health = '/health';
  static const String tags = '/tags';

  // ── Users / Profiles ────────────────────────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersMeProfile = '/users/me/profile';
  static String profile(String userId) => '/profiles/$userId';

  /// My visit + like counters. Separate from [usersMe] because that view is
  /// cached server-side for minutes, which is the wrong freshness for numbers
  /// the owner watches.
  static const String myProfileStats = '/profiles/me/stats';

  /// Counts one visit to someone's profile (deduplicated per day, server-side).
  static String profileView(String userId) => '/profiles/$userId/view';

  // ── Onboarding funnel ───────────────────────────────────────────────────
  /// GET → resume progress; PATCH → set relationshipStatus (step 4).
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingAge = '/onboarding/age';
  static const String onboardingBasics = '/onboarding/basics';
  static const String onboardingIntent = '/onboarding/intent';
  static const String onboardingPersonality = '/onboarding/personality';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String onboardingHardNos = '/onboarding/hard-nos';

  /// Step 8 · finishes the photo step even when nothing was uploaded
  /// (skipped, or storage unavailable) so the funnel never dead-ends.
  static const String onboardingPhoto = '/onboarding/photo';
  static const String onboardingAgreement = '/onboarding/agreement';

  // ── Location (onboarding step 9) ────────────────────────────────────────
  static const String location = '/location';

  /// GET → who can currently see me on the map; PATCH → change it.
  ///
  /// Separate from [usersMe], which carries the same object: that view is
  /// cached server-side for minutes, and a privacy control is the one thing
  /// that must never be read stale.
  static const String locationSharing = '/location/sharing';

  // ── Media (onboarding step 8 · two-phase direct-to-storage upload) ───────
  static const String media = '/media';
  static const String mediaUploadUrl = '/media/upload-url';
  static String mediaComplete(String id) => '/media/$id/complete';
  static String mediaPrimary(String id) => '/media/$id/primary';
  static String mediaItem(String id) => '/media/$id';

  // ── Identity verification (unlocks the adult layer) ─────────────────────
  static const String verificationSession = '/verification/session';
  static const String verificationMe = '/verification/me';
  static String verificationComplete(String sessionId) =>
      '/verification/session/$sessionId/complete';

  // ── Premium subscription ────────────────────────────────────────────────
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionMe = '/subscription/me';
  static const String subscriptionCheckout = '/subscription/checkout';
  static const String subscriptionRestore = '/subscription/restore';
  static const String subscriptionCancel = '/subscription/cancel';

  // ── Discovery / Entitlements ────────────────────────────────────────────
  static const String discoveryNearby = '/discovery/nearby';
  static const String discoveryNearbyCount = '/discovery/nearby/count';
  static const String entitlementsMe = '/entitlements/me';

  // ── Likes / Favorites / Liked-you ───────────────────────────────────────
  static const String likes = '/likes';
  static String likeUser(String userId) => '/likes/$userId';
  static const String likedYou = '/likes/liked-you';
  static const String favorites = '/likes/favorites';

  /// Matches. Deliberately ungated — see the endpoint's own docs.
  static const String mutualLikes = '/likes/mutual';

  // ── Safety (block / report) ─────────────────────────────────────────────
  static const String safetyBlock = '/safety/block';
  static const String safetyBlocks = '/safety/blocks';
  static String safetyUnblock(String userId) => '/safety/block/$userId';
  static const String safetyReport = '/safety/report';

  // ── Rewarded ads (credits that unlock gated surfaces) ───────────────────
  static const String adsReward = '/ads/reward';
  static const String adsHistory = '/ads/history';

  // ── Messaging ───────────────────────────────────────────────────────────
  static const String messagingOpen = '/messaging/open';
  static const String conversations = '/messaging/conversations';

  /// The conversation I already have with one person, or null.
  ///
  /// What lets a screen holding only a user id open the existing thread rather
  /// than an empty one. Read-only: unlike [messagingOpen] it creates nothing
  /// and spends no allowance.
  static String conversationWith(String userId) =>
      '/messaging/conversations/with/$userId';
  static const String unreadCount = '/messaging/unread-count';

  /// The Explore map: people I am vibing with, with generalized positions.
  static const String messagingMap = '/messaging/map';
  static String conversationMessages(String conversationId) =>
      '/messaging/conversations/$conversationId/messages';
  static String conversationRead(String conversationId) =>
      '/messaging/conversations/$conversationId/read';
  static String conversationArchive(String conversationId) =>
      '/messaging/conversations/$conversationId/archive';
  static String conversationUnarchive(String conversationId) =>
      '/messaging/conversations/$conversationId/unarchive';

  /// Mute / unmute, per-user. Stops the thread counting towards the inbox
  /// badge; delivery is unchanged and the other person cannot tell.
  static String conversationMute(String conversationId) =>
      '/messaging/conversations/$conversationId/mute';
  static String conversationUnmute(String conversationId) =>
      '/messaging/conversations/$conversationId/unmute';

  /// PATCH to edit, DELETE to take back — both premium, both sender-only.
  static String message(String messageId) => '/messaging/messages/$messageId';

  /// DELETE — removes the thread from MY inbox only.
  static String conversation(String conversationId) =>
      '/messaging/conversations/$conversationId';
}

/// Socket.io namespaces and event names (see backend presence/messaging
/// gateways). Payload shapes are documented on the socket services.
class SocketConstants {
  SocketConstants._();

  static const String presenceNamespace = '/presence';
  static const String chatNamespace = '/chat';

  // Presence
  static const String heartbeat = 'heartbeat';
  static const String presenceUpdate = 'presence:update';

  // Chat
  static const String chatMessage = 'chat:message';
  static const String chatRead = 'chat:read';
  static const String chatTyping = 'chat:typing';

  /// A message the sender edited or took back. Carries the whole replacement
  /// view rather than a diff, so the receiving client swaps the row and never
  /// has to reason about what changed.
  static const String chatMessageUpdated = 'chat:message:updated';

  /// Pushed to the person who did NOT complete the match — they are elsewhere
  /// in the app and would otherwise not learn about it until they opened the
  /// Mutual tab. Rides the chat namespace, which already keeps a per-user room.
  static const String matchNew = 'match:new';
}
