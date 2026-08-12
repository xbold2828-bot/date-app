import 'package:flutter/material.dart';

/// The Radius palette — warm cream ground, oxblood accent, gold reserved for
/// premium.
///
/// Every colour in the app comes from here. The five original names kept their
/// identifiers and only changed value, so adopting this palette reskins the
/// whole app without editing a single screen.
///
/// ## Contrast
///
/// Measured against [background] (`#F3EDE3`):
///
/// | Colour       | Ratio   | Safe for                        |
/// |--------------|---------|---------------------------------|
/// | [textDark]   | 14.5:1  | anything                        |
/// | [primary]    |  6.18:1 | anything                        |
/// | [textGrey]   |  4.78:1 | text at any size (AA)           |
/// | [iconMuted]  |  3.28:1 | **non-text only** — icons, dots |
///
/// [iconMuted] is the reference design's muted grey. It fails AA for body
/// copy, so [textGrey] — the name every existing screen already calls for
/// secondary text — is the darker, accessible value. Reaching for the
/// decorative grey has to be deliberate.
///
/// The palette is intentionally low-contrast warm neutrals, so [inputBorder]
/// does not reach 3:1 against [background]. That is safe **only because no
/// state is ever signalled by border alone**: a selected control changes fill,
/// border and text weight together. New components must do the same.
class AppColors {
  const AppColors._();

  // --- Ground ---------------------------------------------------------------

  /// App background.
  static const background = Color(0xFFF3EDE3);

  /// Raised surfaces that sit above [background] — sheets, bottom nav, the
  /// chat input bar.
  static const panel = Color(0xFFFAF7F0);

  /// Cards, chips, inputs.
  static const white = Color(0xFFFFFFFF);

  // --- Oxblood --------------------------------------------------------------

  /// Actions, active nav, selection.
  static const primary = Color(0xFFA02C3A);

  /// Gradient end and pressed states for [primary].
  static const primaryDeep = Color(0xFF7E2230);

  /// Fill behind a selected chip or tag pill.
  static const primaryTint = Color(0xFFF5E2E2);

  /// Dashed borders on notice callouts.
  static const primarySoft = Color(0xFFEAD0D0);

  // --- Ink ------------------------------------------------------------------

  /// Primary text.
  static const textDark = Color(0xFF221C18);

  /// Secondary text, at any size. 4.78:1 on [background].
  static const textGrey = Color(0xFF6F675C);

  /// Decorative marks only — icons, presence dots, inactive radar rings.
  /// 3.28:1 on [background]: passes the UI-component bar, fails text. Never
  /// set this on a [Text].
  static const iconMuted = Color(0xFF8B8176);

  // --- Lines ----------------------------------------------------------------

  /// Hairline borders on cards, chips and inputs.
  static const inputBorder = Color(0xFFE5DDD0);

  /// Retained for existing call sites; the same hairline as [inputBorder].
  static const divider = Color(0xFFE5DDD0);

  // --- Semantic -------------------------------------------------------------

  /// Premium, and only premium. If this appears somewhere that does not cost
  /// money, it has stopped meaning anything.
  static const gold = Color(0xFFB9862E);

  /// Fill behind premium surfaces.
  static const goldTint = Color(0xFFF4EAD4);

  /// Verified, online, success.
  static const ok = Color(0xFF2E7D5B);
}
