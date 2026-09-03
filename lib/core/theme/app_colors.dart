import 'package:flutter/material.dart';



abstract final class AppColors {

  static RadiusPalette _active = RadiusPalette.light;

  static RadiusPalette get palette => _active;

  static bool get isDark => _active.brightness == Brightness.dark;

  static bool use(Brightness brightness) {
    if (_active.brightness == brightness) return false;
    _active = brightness == Brightness.dark
        ? RadiusPalette.dark
        : RadiusPalette.light;
    return true;
  }

  static Color get background => _active.background;

  static Color get panel => _active.panel;

  static Color get card => _active.card;

  static Color get primary => _active.primary;

  static Color get primaryDeep => _active.primaryDeep;

  static Color get primaryInk => _active.primaryInk;

  static Color get primaryTint => _active.primaryTint;

  static Color get primarySoft => _active.primarySoft;

  static Color get premium => _active.premium;

  static Color get premiumDeep => _active.premiumDeep;

  static Color get premiumInk => _active.premiumInk;

  static Color get premiumTint => _active.premiumTint;

  static Color get textDark => _active.textDark;

  static Color get textGrey => _active.textGrey;

  static Color get iconMuted => _active.iconMuted;

  static Color get onAccent => _active.onAccent;

  static const onImage = Color(0xFFFFFFFF);

  static Color get inputBorder => _active.inputBorder;

  static Color get divider => _active.inputBorder;

  static Color get ok => _active.ok;

  static Color get danger => _active.danger;

  static Color get warning => _active.warning;

  static Color get warningTint => _active.warningTint;

  static Color get scrim => _active.scrim;

  static const Color secondary = Color(0xFF14B8A6);
  static const Color secondaryDark = secondary;

  static const Color tertiary = Color(0xFFC9B7E3);

  static const Color tertiaryDark = tertiary;

  static const Color backgroundDark = blackColor;

  static const Color surface = blackColor;
  static const Color surfaceDark = whiteColor;

  static const Color lightPillBg = Color(0xFFE9F3F2);

  static const Color blue = Color(0xFF3544FF);

  static const Color coolGrey = Color(0xFF2B2D33);

  static const Color footertext = Color(0xFF636670);

  static const Color accent = Color(0xFFF59E0B);

  static const Color yellowColor = Color(0xFFD88A00);

  static const Color whiteColor = Color(0xFFFFFFFF);

  static const Color blackColor = Color(0xFF000000);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textDisabledDark = Color(0xFF64748B);

  static const Color grayishBlue = Color(0x99E5E7EB);
  static const Color greyColor = Colors.grey;
  static const Color lightGreyColor = Color(0xffE5E7EB);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF334155);

  static const Color transparent = Colors.transparent;

  static const Color themeLight = Color(0xFF0F61A4);

  static const Color themeDark = Color(0xFF3871df);

  static const Color sendMessageColor = Color(0xffDCF8C6);

  static const Color primaryContainerLight = Color.fromRGBO(74, 171, 189, 1.0);
  static const Color primaryContainerDark = Color(0xFF26B8A1);
  static const Color secondaryColor = Color(0xFFFE53BB);

  static const Color textColor = Color(0xFF2B2B2B);
  static const Color lightGrayColor = Color(0x44948282);

  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightTextColor = Color(0xFF403930);
  static const Color darkBackgroundColor = Color(0xFF2B2B2B);
  static const Color darkTextColor = Color(0xFFF3F2FF);
  static const Color babyBlue = Color(0xff81deea);
  static const Color lightRed = Color(0xFFFFCDD2);
  static const Color deepPurple = Color(0xFF673AB7);
  static const Color darkGreen = Color(0xFF26B8A1);

  static const Color lightGreen3 = Color(0xFFDBE6DB);
  static const Color lightGreen = Color(0xFFB6E7B8);
  static const Color lightGreen2 = Color(0xFF90D5C7);
  static const Color redPink = Color(0xfff48fb1);
  static const Color violet = Color(0xffcf94da);
  static const Color lightPurple = Color(0xFFB29BE3);
  static const Color redOrange = Color(0xffffab91);
  static const Color lightBlue = Color(0xFFBBDEFB);

  static const Color youtubeRed = Color.fromARGB(255, 255, 0, 0);
  static const Color youtubeRedDark = Color.fromARGB(255, 230, 0, 0);
  static const Color youtubeRedLight = Color.fromARGB(255, 179, 0, 0);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF9FAFB);

  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  static const Color lightBorder = Color(0xFFE5E7EB);

  static const Color darkBackground = Color(
    0xFF0F172A,
  );
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF334155);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  static const Color darkBorder = Color(0xFF334155);

  static const List<Color> kConcernCategoryColors = [
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF16A34A),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFFDB2777),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
  ];

  static const paper = Color(0xFFF6F4EC);
  static const ink = Color(0xFF1E2A3B);
  static const inkSoft = Color(0xFF5B6A7C);
  static const green = Color(0xFF2E7D5F);
  static const greenSoft = Color(0xFFDCEBE3);
  static const hairline = Color(0xFFE4E0D3);
  static const cardShadow = Color(0x14140F0A);
}

abstract final class AppMapColors {

  static const land = Color(0xFFFAFAFF);

  static const water = Color(0xFFDCE8FF);

  static const waterway = Color(0xFFC7DBFB);

  static const park = Color(0xFFDDF3E9);

  static const woodland = Color(0xFFCFEEDD);

  static const highway = Color(0xFF9BB6F1);

  static const roadMajor = Color(0xFFE3E4F2);

  static const roadMinor = Color(0xFFEFF0FA);

  static const buildingLow = Color(0xFFE9ECFA);

  static const buildingMid = Color(0xFFE2E0F8);

  static const buildingTall = Color(0xFFD2CCF3);

  static const label = Color(0xFF303036);

  static const plum = Color(0xFF7C4DFF);

  static const glow = Color(0xFFB9A5F5);

  static const markerStart = Color(0xFF4A7FE8);

  static const markerEnd = plum;

  static const you = Color(0xFF6236D8);

  static const youPulse = Color(0xFF9B7FE8);
}


@immutable
class RadiusPalette {
  const RadiusPalette({
    required this.brightness,
    required this.background,
    required this.panel,
    required this.card,
    required this.primary,
    required this.primaryDeep,
    required this.primaryInk,
    required this.primaryTint,
    required this.primarySoft,
    required this.premium,
    required this.premiumDeep,
    required this.premiumInk,
    required this.premiumTint,
    required this.textDark,
    required this.textGrey,
    required this.iconMuted,
    required this.inputBorder,
    required this.onAccent,
    required this.ok,
    required this.danger,
    required this.warning,
    required this.warningTint,
    required this.scrim,
  });

  final Brightness brightness;

  final Color background;
  final Color panel;
  final Color card;

  final Color primary;
  final Color primaryDeep;
  final Color primaryInk;
  final Color primaryTint;
  final Color primarySoft;

  final Color premium;
  final Color premiumDeep;
  final Color premiumInk;
  final Color premiumTint;

  final Color textDark;
  final Color textGrey;
  final Color iconMuted;

  final Color inputBorder;

  final Color onAccent;

  final Color ok;
  final Color danger;
  final Color warning;
  final Color warningTint;

  final Color scrim;

  static const light = RadiusPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF4A7FE8),
    primaryDeep: Color(0xFF2E5CBF),
    primaryInk: Color(0xFF2E5CBF),
    primaryTint: Color(0xFFE8EFFC),
    primarySoft: Color(0xFFC9D9F8),
    premium: Color(0xFF7C4DFF),
    premiumDeep: Color(0xFF5E2BE0),
    premiumInk: Color(0xFF5E2BE0),
    premiumTint: Color(0xFFEFE9FF),
    textDark: Color(0xFF141428),
    textGrey: Color(0xFF6A6A85),
    iconMuted: Color(0xFF8A8AA3),
    inputBorder: Color(0xFFE6E6F5),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFB45309),
    warningTint: Color(0xFFFEF3C7),
    scrim: Color(0x66141428),
  );

  static const dark = RadiusPalette(
    brightness: Brightness.dark,
    background: Color(0xFF101018),
    panel: Color(0xFF16161F),
    card: Color(0xFF1B1B29),
    primary: Color(0xFF7DA6FF),
    primaryDeep: Color(0xFF5B87F0),
    primaryInk: Color(0xFFA9C4FF),
    primaryTint: Color(0xFF1E2A47),
    primarySoft: Color(0xFF33436B),
    premium: Color(0xFFA78BFA),
    premiumDeep: Color(0xFF7C4DFF),
    premiumInk: Color(0xFFC4B0FD),
    premiumTint: Color(0xFF251C42),
    textDark: Color(0xFFF0F0F8),
    textGrey: Color(0xFF9A9AB5),
    iconMuted: Color(0xFF74748C),
    inputBorder: Color(0xFF2E2E44),
    onAccent: Color(0xFF0B0B14),
    ok: Color(0xFF22C55E),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0xFF3A2E12),
    scrim: Color(0x99000000),
  );
}