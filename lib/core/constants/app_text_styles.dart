import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The Radius type scale.
///
/// Two families, each doing one job. **Fraunces** (serif, display) marks the
/// beginning of things — screen titles, sheet titles, avatar initials, prices.
/// It never sets body copy, form labels or button text. **DM Sans** sets
/// everything else.
///
/// ## Both families are variable fonts
///
/// **Weight works the way you expect.** Measured on Flutter 3.44.8, a plain
/// `fontWeight: w700` moves the `wght` axis and renders identically to an
/// explicit `FontVariation('wght', 700)`. Screens setting raw `fontWeight:`
/// are fine.
///
/// **The optical-size axis is not automatic.** A browser applies `opsz` for
/// you; Flutter does not, and there is no [TextStyle] field for it. Each
/// style below sets `opsz` to its own point size through [FontVariation],
/// which is what the axis is for — display sizes get tighter, more contrasted
/// letterforms, small sizes get sturdier ones. Left unset, everything renders
/// at one optical size and the large type looks slack. The same goes for
/// Fraunces' `SOFT` and `WONK`.
///
/// So these styles set `fontWeight` *and* a matching `wght` variation. The
/// variation is redundant today and harmless, and it keeps the styles correct
/// if the axis mapping ever changes.
///
/// Prefer [_fraunces] / [_dmSans] over hand-built [TextStyle]s so the optical
/// size is never forgotten.
///
/// ## Why these are getters
///
/// Each token bakes a colour in from [AppColors], and [AppColors] now resolves
/// per theme. A `static final` would capture whichever palette happened to be
/// active the first time it was touched and keep serving that colour after the
/// user flips to dark. Getters re-resolve on every read, which costs one small
/// allocation per build and buys a type scale that is actually theme-aware.
class AppTextStyles {
  const AppTextStyles._();

  // Axis limits, from the font files themselves. Clamping here means a caller
  // asking for an out-of-range optical size gets the nearest valid instance
  // instead of an undefined one.
  static const _frauncesOpszMin = 9.0;
  static const _frauncesOpszMax = 144.0;
  static const _dmSansOpszMin = 9.0;
  static const _dmSansOpszMax = 40.0;

  static TextStyle _fraunces({
    required double size,
    required int weight,
    double? opsz,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    final opticalSize =
        (opsz ?? size).clamp(_frauncesOpszMin, _frauncesOpszMax);
    return TextStyle(
      fontFamily: 'Fraunces',
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textDark,
      fontWeight: _weightOf(weight),
      fontVariations: [
        FontVariation('wght', weight.toDouble()),
        FontVariation('opsz', opticalSize),
        // The reference design uses conventional letterforms; the quirky
        // alternates and softened terminals stay off.
        const FontVariation('SOFT', 0),
        const FontVariation('WONK', 0),
      ],
    );
  }

  static TextStyle _dmSans({
    required double size,
    required int weight,
    double? opsz,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    final opticalSize = (opsz ?? size).clamp(_dmSansOpszMin, _dmSansOpszMax);
    return TextStyle(
      fontFamily: 'DM Sans',
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textDark,
      fontWeight: _weightOf(weight),
      fontVariations: [
        FontVariation('wght', weight.toDouble()),
        FontVariation('opsz', opticalSize),
      ],
    );
  }

  static FontWeight _weightOf(int weight) => switch (weight) {
        <= 100 => FontWeight.w100,
        <= 200 => FontWeight.w200,
        <= 300 => FontWeight.w300,
        <= 400 => FontWeight.w400,
        <= 500 => FontWeight.w500,
        <= 600 => FontWeight.w600,
        <= 700 => FontWeight.w700,
        <= 800 => FontWeight.w800,
        _ => FontWeight.w900,
      };

  // --- Display (Fraunces) ---------------------------------------------------

  /// Screen titles. "First — your age."
  static TextStyle get display => _fraunces(
    size: 30,
    weight: 700,
    height: 1.25,
    letterSpacing: -0.4,
  );

  /// Sheet titles and the wordmark.
  static TextStyle get title => _fraunces(
    size: 21,
    weight: 700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// The name over a profile hero image.
  static TextStyle get hero => _fraunces(
    size: 28,
    weight: 700,
    height: 1.28,
    letterSpacing: -0.3,
    color: AppColors.onImage,
  );

  /// A single letter standing in for a photo. Sized by the caller to fit its
  /// avatar, with the optical size following along.
  ///
  /// The only token that sets a line box tighter than the font's full ascent
  /// plus descent, and deliberately: callers pass `name[0].toUpperCase()`, so
  /// there is never a descender to clip, and the descender space would push a
  /// capital off-centre inside its circle.
  static TextStyle avatarInitial(double size) => _fraunces(
        size: size,
        weight: 600,
        height: 1,
        color: AppColors.onImage,
      );

  // --- UI (DM Sans) ---------------------------------------------------------

  /// Small uppercase lead-in, in accent blue. "18+ · Verified people only"
  static TextStyle get eyebrow => _dmSans(
    size: 11,
    weight: 700,
    height: 1.3,
    letterSpacing: 0.14 * 11,
    color: AppColors.primaryInk,
  );

  /// Uppercase section heading between groups. "DISPLAY NAME"
  static TextStyle get label => _dmSans(
    size: 11,
    weight: 700,
    height: 1.3,
    letterSpacing: 0.13 * 11,
    color: AppColors.textGrey,
  );

  /// Body copy.
  static TextStyle get body => _dmSans(size: 14.5, weight: 400, height: 1.45);

  /// Body copy carrying emphasis.
  static TextStyle get bodyStrong =>
      _dmSans(size: 14.5, weight: 500, height: 1.45);

  /// Secondary body copy. Accessible at this size — see [AppColors.textGrey].
  static TextStyle get bodyMuted => _dmSans(
    size: 14.5,
    weight: 400,
    height: 1.45,
    color: AppColors.textGrey,
  );

  /// All buttons.
  static TextStyle get button => _dmSans(
    size: 16,
    weight: 700,
    height: 1.35,
    letterSpacing: 0.16,
    color: AppColors.onAccent,
  );

  /// Metadata, timestamps, distance bands.
  static TextStyle get caption => _dmSans(
    size: 12.5,
    weight: 500,
    height: 1.35,
    color: AppColors.textGrey,
  );

  /// The label inside a chip.
  static TextStyle get chip => _dmSans(size: 14, weight: 500, height: 1.3);

  /// A chip's label once selected — heavier, so selection survives being read
  /// in greyscale.
  static TextStyle get chipSelected => _dmSans(
    size: 14,
    weight: 700,
    height: 1.3,
    color: AppColors.primaryInk,
  );
}
