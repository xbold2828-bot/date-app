abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/sign_in';
  static const String signInOtp = '/otp';
  static const String notifications = '/notifications';
  static const String dashboard = '/dashboard';
  static const String forceUpdate = '/force_update';
  static const String archivedChats = '/archived-chats';
  static const String buyPremium = '/buy-premium';
  static const String internet = '/internet';
  static const String locationSharing = '/location-sharing';

  // Onboarding funnel, in order.
  static const String age = '/onboarding/age';
  static const String basics = '/onboarding/basics';
  static const String intent = '/onboarding/intent';
  static const String status = '/onboarding/status';
  static const String preferences = '/onboarding/preferences';
  static const String photos = '/onboarding/photos';
  static const String location = '/onboarding/location';
  static const String agreement = '/onboarding/agreement';
}