import 'package:flutter/material.dart';

extension AppTextExtension on BuildContext {

  /// Base TextStyle for the entire app
  TextStyle appTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
    FontStyle? fontStyle,
    Color? color,
    String? fontFamily,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextBaseline? textBaseline,
    Paint? foreground,
    Paint? background,
  }) {
    final theme = Theme.of(this);

    return TextStyle(
      fontSize: fontSize ,
      fontWeight: fontWeight ,
      fontStyle: fontStyle,
      color: color ?? theme.colorScheme.onSurface,
      fontFamily: fontFamily ?? 'Fraunces',
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      shadows: shadows,
      fontFeatures: fontFeatures,
      textBaseline: textBaseline,
      foreground: foreground,
      background: background,
    );
  }
}
