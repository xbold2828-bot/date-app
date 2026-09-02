abstract final class AppConstants {
  static const String appName = "Cozune";
  static const String packageName = "com.cozune.app";

  /// Privacy Policy - Terms & Conditions
  static const String _baseUrl = "https://cozune.in/admin/user";
  static const String termsAndCondition = "$_baseUrl/terms-and-conditions";
  static const String privacyPolicy = "$_baseUrl/privacy-policy";

  /// Android or iOS
  static const String androidAppId = "com.cozune.app";
  static const String iosAppId = "com.cozune.app";

  static String playStoreUrlMaker({String appId = packageName}) =>
      'https://play.google.com/store/apps/details?id=$appId';
}
