import 'package:flutter/material.dart';

import '../constants/app_text_styles.dart';
import 'app_colors.dart';

/// Assembles the app's [ThemeData] from the colour and type tokens.
///
/// This is deliberately the only place `ThemeData` is constructed. Setting
/// `fontFamily` here is what carries the typeface to every screen that has not
/// been individually restyled yet — including screens that build their own
/// [TextStyle]s, since those merge onto the theme's family.
///
/// There are two themes and one builder. [_build] takes the palette explicitly
/// rather than reading [AppColors], because both themes are constructed up
/// front — before the app has decided which one it is showing — and reading the
/// façade here would bake the light palette into the dark theme.
///
/// The type tokens are the exception: they *do* read [AppColors], so
/// [_textTheme] is only correct for whichever palette is active when it runs.
/// That is fine because [AppColors] is swapped in `MaterialApp.builder` before
/// any screen builds, and the per-slot colours are re-applied here from the
/// palette passed in.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(RadiusPalette.light);

  static ThemeData get dark => _build(RadiusPalette.dark);

  static ThemeData _build(RadiusPalette p) {
    final base = p.brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.inputBorder,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: base.colorScheme.copyWith(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onAccent,
        primaryContainer: p.primaryTint,
        onPrimaryContainer: p.primaryInk,
        secondary: p.premium,
        onSecondary: p.onAccent,
        secondaryContainer: p.premiumTint,
        onSecondaryContainer: p.premiumInk,
        surface: p.card,
        onSurface: p.textDark,
        surfaceContainerHighest: p.panel,
        outline: p.inputBorder,
        outlineVariant: p.inputBorder,
        error: p.danger,
        onError: p.brightness == Brightness.dark
            ? const Color(0xFF14060A)
            : const Color(0xFFFFFFFF),
        scrim: p.scrim,
      ),

      textTheme: _textTheme(base.textTheme, p),
      primaryTextTheme: _textTheme(base.primaryTextTheme, p),

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textDark,
        elevation: 0,
        centerTitle: false,
      ),

      iconTheme: IconThemeData(color: p.textDark),

      // 16pt corners and a 700-weight label, matching the reference's primary
      // action. Screens that still build their own buttons override this; the
      // migration removes those.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.inputBorder,
          disabledForegroundColor: p.textGrey,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTextStyles.button.copyWith(color: p.onAccent),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.card,
          foregroundColor: p.textDark,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: p.inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTextStyles.button.copyWith(color: p.textDark),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryInk,
          textStyle: AppTextStyles.bodyStrong.copyWith(color: p.primaryInk),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.body.copyWith(color: p.textGrey),
        border: _inputBorder(p.inputBorder),
        enabledBorder: _inputBorder(p.inputBorder),
        focusedBorder: _inputBorder(p.primary),
        errorBorder: _inputBorder(p.danger),
        focusedErrorBorder: _inputBorder(p.danger),
      ),

      // In light mode the sheet, the card and the page are all the same white,
      // so a sheet has nothing but its edge to separate it from what it covers.
      // Hence the hairline and the drop shadow — without them the panel does
      // not read as lifted, it reads as the page having grown corners.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.inputBorder),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textDark,
        contentTextStyle: AppTextStyles.bodyStrong.copyWith(
          color: p.background,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.inputBorder,
        linearMinHeight: 3,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.primaryInk,
        unselectedLabelColor: p.textGrey,
        indicatorColor: p.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: p.inputBorder,
        labelStyle: AppTextStyles.bodyStrong.copyWith(color: p.primaryInk),
        unselectedLabelStyle: AppTextStyles.body.copyWith(color: p.textGrey),
      ),

      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.inputBorder,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onAccent
              : p.background,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.primary : p.inputBorder,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.primary
              : p.inputBorder,
        ),
      ),

      // Both sit on the page colour, so the default surface-on-surface is
      // invisible without an edge.
      dialogTheme: DialogThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.inputBorder),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.inputBorder),
          borderRadius: BorderRadius.circular(14),
        ),
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
  static TextTheme _textTheme(TextTheme base, RadiusPalette p) {
    // Order matters. `apply(fontFamily:)` overwrites the family on *every*
    // slot, so it has to run first, on the Material defaults — running it
    // after would strip Fraunces off the display styles and render the whole
    // app in DM Sans.
    return base
        .apply(
          bodyColor: p.textDark,
          displayColor: p.textDark,
          // The safety net: any slot not named below still gets DM Sans
          // rather than falling back to Roboto.
          fontFamily: 'DM Sans',
        )
        .copyWith(
          displayLarge: AppTextStyles.display.copyWith(color: p.textDark),
          displayMedium: AppTextStyles.display.copyWith(color: p.textDark),
          displaySmall: AppTextStyles.title.copyWith(color: p.textDark),
          headlineLarge: AppTextStyles.display.copyWith(color: p.textDark),
          // `hero` is white on purpose — it sets a name over a photograph. The
          // Material slot has no photo behind it, so it takes the ink colour.
          headlineMedium: AppTextStyles.hero.copyWith(color: p.textDark),
          headlineSmall: AppTextStyles.title.copyWith(color: p.textDark),
          titleLarge: AppTextStyles.title.copyWith(color: p.textDark),
          titleMedium: AppTextStyles.bodyStrong.copyWith(color: p.textDark),
          titleSmall: AppTextStyles.bodyStrong.copyWith(color: p.textDark),
          bodyLarge: AppTextStyles.body.copyWith(color: p.textDark),
          bodyMedium: AppTextStyles.body.copyWith(color: p.textDark),
          bodySmall: AppTextStyles.caption.copyWith(color: p.textGrey),
          labelLarge: AppTextStyles.button.copyWith(color: p.textDark),
          labelMedium: AppTextStyles.label.copyWith(color: p.textGrey),
          labelSmall: AppTextStyles.label.copyWith(color: p.textGrey),
        );
  }
}
