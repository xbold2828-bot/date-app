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

/// The Explore map palette.
///
/// Kept apart from [AppColors] because it answers a different question. The
/// main palette dresses *chrome* — surfaces, text, controls — and every value
/// in it is chosen against [AppColors.background]. These dress *terrain*, and
/// are chosen against each other: land against water against park, at 5% of
/// the screen area each, under a marker layer that has to stay the loudest
/// thing on the map.
///
/// Terrain is pastel and cool — lavender buildings, pastel green parks, pastel
/// blue water — while everything representing a *person* stays oxblood-to-plum,
/// so Explore reads as the same product as the Radar tab rather than a map
/// bolted onto it. The coral used for motorways is the one warm note, and it
/// is deliberately desaturated enough to sit under a marker without competing.
///
/// The terrain values are also consumed as hex strings by
/// `assets/map/explore_style.json`; the two must be changed together. Dart
/// cannot see inside that JSON, so `test/explore_map_style_test.dart` asserts
/// they still agree.
class AppMapColors {
  const AppMapColors._();

  // --- Terrain --------------------------------------------------------------

  /// Land, and the map's background.
  static const land = Color(0xFFFAF8FC);

  /// Lakes and ocean.
  static const water = Color(0xFFDCEEFF);

  /// Rivers, streams, canals — a touch stronger, so a river reads as a line
  /// rather than as a seam in the land.
  static const waterway = Color(0xFFC9E3FB);

  /// Parks and grass.
  static const park = Color(0xFFDDF3E4);

  /// Woodland and forest.
  static const woodland = Color(0xFFCFEED9);

  /// Motorways and trunk roads.
  static const highway = Color(0xFFF19BB9);

  /// Primary and secondary roads.
  static const roadMajor = Color(0xFFE6E0EC);

  /// Everything else with a name.
  static const roadMinor = Color(0xFFF1EDF6);

  /// Buildings, short. Nearly all of them.
  static const buildingLow = Color(0xFFF5E2EE);

  /// Buildings, mid-rise.
  static const buildingMid = Color(0xFFE9DDF6);

  /// Buildings, tall.
  static const buildingTall = Color(0xFFD8C5F0);

  /// Map labels. Charcoal, never pure black — pure black on a pastel ground
  /// reads as a hole punched in the map.
  static const label = Color(0xFF303036);

  // --- People ---------------------------------------------------------------

  /// The plum end of every people gradient. Pairs with [AppColors.primary].
  static const plum = Color(0xFF7A3E86);

  /// The lavender a marker's glow fades out into.
  static const glow = Color(0xFFC4A5DA);

  /// Start of the marker ring and cluster gradient (oxblood).
  static const markerStart = AppColors.primary;

  /// End of the marker ring and cluster gradient.
  static const markerEnd = plum;

  /// The current user. Distinct from [markerStart] on purpose — "you" must not
  /// look like one more dating profile on the map.
  static const you = Color(0xFF6D3E9E);

  /// Fill of the ring pulsing out from the current user.
  static const youPulse = Color(0xFF9B6FD4);
}
