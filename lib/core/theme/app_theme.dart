import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Assembles the app's single [ThemeData] from the colour and type tokens.
///
/// This is deliberately the only place `ThemeData` is constructed. Setting
/// `fontFamily` here is what carries the typeface to every screen that has not
/// been individually restyled yet — including screens that build their own
/// [TextStyle]s, since those merge onto the theme's family.
///
/// There is one theme. The design has no dark mode, so there is no
/// `darkTheme` and no [ThemeExtension]: the tokens are plain constants, which
/// keeps a wide restyle from also being an API migration. If dark mode is ever
/// wanted, everything to swap already lives in two files.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.inputBorder,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primaryTint,
        onPrimaryContainer: AppColors.primaryDeep,
        secondary: AppColors.gold,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.goldTint,
        surface: AppColors.white,
        onSurface: AppColors.textDark,
        surfaceContainerHighest: AppColors.panel,
        outline: AppColors.inputBorder,
        outlineVariant: AppColors.inputBorder,
        error: AppColors.primaryDeep,
      ),

      textTheme: _textTheme(base.textTheme),
      primaryTextTheme: _textTheme(base.primaryTextTheme),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
      ),

      // 16pt corners and a 700-weight label, matching the reference's primary
      // action. Screens that still build their own buttons override this; the
      // migration removes those.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.inputBorder,
          disabledForegroundColor: AppColors.textGrey,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.bodyStrong,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textGrey),
        border: _inputBorder(AppColors.inputBorder),
        enabledBorder: _inputBorder(AppColors.inputBorder),
        focusedBorder: _inputBorder(AppColors.primary),
        errorBorder: _inputBorder(AppColors.primaryDeep),
        focusedErrorBorder: _inputBorder(AppColors.primaryDeep),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textDark,
        contentTextStyle: AppTextStyles.bodyStrong.copyWith(
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.inputBorder,
        linearMinHeight: 3,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textGrey,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.inputBorder,
        labelStyle: AppTextStyles.bodyStrong,
        unselectedLabelStyle: AppTextStyles.body,
      ),

      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.inputBorder,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
      ),

      // Both sit on cream, so the default white-on-white is invisible.
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  /// Maps the token scale onto Material's slots.
  ///
  /// `bodyMedium` is the one that matters most: it is what a bare [Text] with
  /// no style resolves to, and what every screen-local [TextStyle] merges on
  /// top of. Getting DM Sans in there is what carries the typeface across
  /// screens this migration has not reached yet.
  static TextTheme _textTheme(TextTheme base) {
    // Order matters. `apply(fontFamily:)` overwrites the family on *every*
    // slot, so it has to run first, on the Material defaults — running it
    // after would strip Fraunces off the display styles and render the whole
    // app in DM Sans.
    return base
        .apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
          // The safety net: any slot not named below still gets DM Sans
          // rather than falling back to Roboto.
          fontFamily: 'DM Sans',
        )
        .copyWith(
          displayLarge: AppTextStyles.display,
          displayMedium: AppTextStyles.display,
          displaySmall: AppTextStyles.title,
          headlineLarge: AppTextStyles.display,
          headlineMedium: AppTextStyles.hero,
          headlineSmall: AppTextStyles.title,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.bodyStrong,
          titleSmall: AppTextStyles.bodyStrong,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button.copyWith(
            color: AppColors.textDark,
          ),
          labelMedium: AppTextStyles.label,
          labelSmall: AppTextStyles.label,
        );
  }
}
