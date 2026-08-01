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

  // ── Onboarding funnel ───────────────────────────────────────────────────
  /// GET → resume progress; PATCH → set relationshipStatus (step 4).
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingAge = '/onboarding/age';
  static const String onboardingBasics = '/onboarding/basics';
  static const String onboardingIntent = '/onboarding/intent';
  static const String onboardingPersonality = '/onboarding/personality';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String onboardingHardNos = '/onboarding/hard-nos';
  static const String onboardingAgreement = '/onboarding/agreement';

  // ── Location (onboarding step 9) ────────────────────────────────────────
  static const String location = '/location';

  // ── Discovery / Entitlements ────────────────────────────────────────────
  static const String discoveryNearby = '/discovery/nearby';
  static const String entitlementsMe = '/entitlements/me';

  // ── Likes / Favorites / Liked-you ───────────────────────────────────────
  static const String likes = '/likes';
  static String likeUser(String userId) => '/likes/$userId';
  static const String likedYou = '/likes/liked-you';
  static const String favorites = '/likes/favorites';

  // ── Messaging ───────────────────────────────────────────────────────────
  static const String messagingOpen = '/messaging/open';
  static const String conversations = '/messaging/conversations';
  static const String unreadCount = '/messaging/unread-count';
  static String conversationMessages(String conversationId) =>
      '/messaging/conversations/$conversationId/messages';
  static String conversationRead(String conversationId) =>
      '/messaging/conversations/$conversationId/read';
  static String conversationArchive(String conversationId) =>
      '/messaging/conversations/$conversationId/archive';
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
}
