import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';

class AppText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  final FontStyle? fontStyle;
  final Color? color;
  final String? fontFamily;

  final double? letterSpacing;
  final double? wordSpacing;
  final double? height;

  final TextDecoration? decoration;
  final Color? decorationColor;
  final TextDecorationStyle? decorationStyle;
  final double? decorationThickness;

  final List<Shadow>? shadows;
  final List<FontFeature>? fontFeatures;

  final bool isEllipsis;
  final int? maxLines;

  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final TextDirection? textDirection;
  final Locale? locale;

  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  final Paint? foreground;
  final Paint? background;

  const AppText({
    super.key,
    required this.text,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w400,

    this.fontStyle,
    this.color,
    this.fontFamily,
    this.letterSpacing,
    this.wordSpacing,
    this.height,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.shadows,
    this.fontFeatures,

    this.isEllipsis = false,
    this.maxLines,

    this.textAlign,
    this.overflow,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.textWidthBasis,
    this.textHeightBehavior,

    this.foreground,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      overflow: overflow ?? (isEllipsis ? TextOverflow.ellipsis : null),
      maxLines: isEllipsis ? (maxLines ?? 1) : maxLines,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      style: context.appTextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
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
        foreground: foreground,
        background: background,
      ),
    );
  }
}
