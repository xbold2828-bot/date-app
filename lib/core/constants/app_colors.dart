import 'package:flutter/material.dart';

/// The Radius palette — a white ground, a blue accent, purple reserved for
/// premium, and a dark mode that swaps every value without any screen knowing.
///
/// ## How this file works
///
/// [RadiusPalette] holds one complete set of values; there are two of them,
/// [RadiusPalette.light] and [RadiusPalette.dark]. [AppColors] is a thin façade
/// of getters over whichever one is currently active, so a screen keeps writing
/// `AppColors.card` and gets the right colour for the mode it is being drawn
/// in. Nothing outside this file names a palette.
///
/// The active palette is set by `MaterialApp.builder` in `main.dart`, above
/// every screen, before anything below it builds.
///
/// **These are getters, not constants.** A widget reading one cannot be
/// `const`, which is what makes the swap visible at all. If you add a token,
/// add it to [RadiusPalette], to both palettes, and to the façade.
///
/// ## Ink tokens, and why there are three of them
///
/// White is not one colour in this design, it is three jobs, and only one of
/// them survives the dark swap:
///
/// * [card] — the surface under cards, chips, inputs. White in light,
///   `#1B1B29` in dark.
/// * [onAccent] — ink sitting *on* a [primary] or [premium] fill. White in
///   light, near-black in dark, because the dark accents are pale.
/// * [onImage] — ink over a photograph, gradient scrim or map marker. Always
///   white, in both modes, because a photo is a photo either way.
///
/// Reaching for the wrong one is invisible in light mode and obvious in dark,
/// which is exactly the bug this split exists to prevent.
///
/// ## Contrast
///
/// Every promise below is asserted by `test/design_system/tokens_test.dart`,
/// for **both** palettes. Measured on that palette's own [background]:
///
/// | Token          | Light   | Dark    | Safe for                        |
/// |----------------|---------|---------|---------------------------------|
/// | [textDark]     | 18.1:1  | 16.7:1  | anything                        |
/// | [textGrey]     |  5.2:1  |  6.9:1  | text at any size (AA)           |
/// | [primaryInk]   |  6.2:1  | 10.8:1  | text at any size (AA)           |
/// | [iconMuted]    |  3.4:1  |  4.2:1  | **non-text only** — icons, dots |
/// | [primary]      |  3.8:1  |  7.9:1  | **fills and controls only**     |
///
/// [primary] is the brand blue exactly as specified, and at 3.8:1 on white it
/// clears the 3:1 bar for a UI component but not the 4.5:1 bar for text. So it
/// fills buttons, marks active tabs and draws controls — and [primaryInk], the
/// deeper blue, is what an accent-coloured *word* is set in. Same for
/// [premium] / [premiumInk].
///
/// [inputBorder] does not reach 3:1 against [background] in either mode. That
/// is safe **only because no state is ever signalled by border alone**: a
/// selected control changes fill, border and text weight together. New
/// components must do the same.
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

  /// The default. A pure white ground — cards, sheets and the app background
  /// are all `#FFFFFF`, and hierarchy comes from [inputBorder] hairlines and
  /// shadow rather than from tinted surfaces.
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

  /// The 🌙 mode. [background] and [card] are the two values the design fixes;
  /// [panel] sits between them so a sheet still reads as lifted off the ground,
  /// and the accents lighten because a mid-blue disappears against `#101018`.
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
    // The dark accents are pale, so ink on top of them goes near-black.
    onAccent: Color(0xFF0B0B14),
    ok: Color(0xFF22C55E),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0xFF3A2E12),
    scrim: Color(0x99000000),
  );
}

/// Every colour in the app, resolved for the mode currently being drawn.
///
/// See [RadiusPalette] for what each token means and which ones are safe for
/// text.
class AppColors {
  const AppColors._();

  static RadiusPalette _active = RadiusPalette.light;

  /// The palette currently in force. Read this only when you need the whole
  /// set — a single colour should come from the getters below.
  static RadiusPalette get palette => _active;

  /// True while the dark palette is active. For the rare widget that has to
  /// branch on mode — a shadow that only makes sense over a light ground, say
  /// — rather than for picking between two colours, which is what tokens are.
  static bool get isDark => _active.brightness == Brightness.dark;

  /// Swaps the active palette. Returns whether it actually changed, so the
  /// caller can skip the rebuild sweep when it did not.
  ///
  /// Called from `MaterialApp.builder`, which sits above every screen — do not
  /// call it from a widget.
  static bool use(Brightness brightness) {
    if (_active.brightness == brightness) return false;
    _active = brightness == Brightness.dark
        ? RadiusPalette.dark
        : RadiusPalette.light;
    return true;
  }

  // --- Ground ---------------------------------------------------------------

  /// App background.
  static Color get background => _active.background;

  /// Raised surfaces that sit above [background] — sheets, bottom nav, the
  /// chat input bar.
  static Color get panel => _active.panel;

  /// Cards, chips, inputs. **Not** ink on an accent fill — that is [onAccent]
  /// — and not ink over a photo, which is [onImage].
  static Color get card => _active.card;

  // --- Accent (blue) --------------------------------------------------------

  /// Actions, active nav, selection. A fill and control colour; for an
  /// accent-coloured *word*, use [primaryInk].
  static Color get primary => _active.primary;

  /// Gradient end and pressed states for [primary].
  static Color get primaryDeep => _active.primaryDeep;

  /// Accent text and accent icons that have to be legible — links, the label
  /// on a selected chip. AA at any size on both [background] and [primaryTint].
  static Color get primaryInk => _active.primaryInk;

  /// Fill behind a selected chip or tag pill.
  static Color get primaryTint => _active.primaryTint;

  /// Dashed borders on notice callouts.
  static Color get primarySoft => _active.primarySoft;

  // --- Premium (purple) -----------------------------------------------------

  /// Premium, and only premium. If this appears somewhere that does not cost
  /// money, it has stopped meaning anything.
  static Color get premium => _active.premium;

  /// Gradient end and pressed states for [premium].
  static Color get premiumDeep => _active.premiumDeep;

  /// Premium text and premium icons that have to be legible.
  static Color get premiumInk => _active.premiumInk;

  /// Fill behind premium surfaces.
  static Color get premiumTint => _active.premiumTint;

  // --- Ink ------------------------------------------------------------------

  /// Primary text.
  static Color get textDark => _active.textDark;

  /// Secondary text, at any size.
  static Color get textGrey => _active.textGrey;

  /// Decorative marks only — icons, presence dots, inactive radar rings.
  /// Passes the UI-component bar, fails text. Never set this on a [Text].
  static Color get iconMuted => _active.iconMuted;

  /// Ink on a [primary] or [premium] fill: the label inside a filled button,
  /// the tick inside a selected checkbox. White in light mode, near-black in
  /// dark, because the dark accents are pale.
  static Color get onAccent => _active.onAccent;

  /// Ink over a photograph, a gradient scrim, or a map marker. Always white —
  /// a photo does not change colour with the theme, so neither does the text
  /// on top of it.
  static const onImage = Color(0xFFFFFFFF);

  // --- Lines ----------------------------------------------------------------

  /// Hairline borders on cards, chips and inputs.
  static Color get inputBorder => _active.inputBorder;

  /// Retained for existing call sites; the same hairline as [inputBorder].
  static Color get divider => _active.inputBorder;

  // --- Semantic -------------------------------------------------------------

  /// Verified, online, success.
  static Color get ok => _active.ok;

  /// Destructive actions and error states.
  static Color get danger => _active.danger;

  /// Caution notices. Amber, and distinct from [premium] — a warning that
  /// looks like an upsell reads as an upsell.
  static Color get warning => _active.warning;

  /// Fill behind a warning notice.
  static Color get warningTint => _active.warningTint;

  /// Wash behind a modal or over the bottom of a photo.
  static Color get scrim => _active.scrim;
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
/// **The map does not have a dark mode.** These are plain constants, and the
/// map renders the same in both themes — the tiles, their labels and the photos
/// on the markers are light either way, and a half-darkened map reads as a
/// rendering fault rather than a design. Marker ink is [AppColors.onImage] for
/// the same reason.
///
/// Terrain is pastel and cool — lavender buildings, pastel green parks, pastel
/// blue water — while everything representing a *person* stays blue-to-violet,
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
  static const land = Color(0xFFFAFAFF);

  /// Lakes and ocean.
  static const water = Color(0xFFDCE8FF);

  /// Rivers, streams, canals — a touch stronger, so a river reads as a line
  /// rather than as a seam in the land.
  static const waterway = Color(0xFFC7DBFB);

  /// Parks and grass.
  static const park = Color(0xFFDDF3E9);

  /// Woodland and forest.
  static const woodland = Color(0xFFCFEEDD);

  /// Motorways and trunk roads.
  static const highway = Color(0xFF9BB6F1);

  /// Primary and secondary roads.
  static const roadMajor = Color(0xFFE3E4F2);

  /// Everything else with a name.
  static const roadMinor = Color(0xFFEFF0FA);

  /// Buildings, short. Nearly all of them.
  static const buildingLow = Color(0xFFE9ECFA);

  /// Buildings, mid-rise.
  static const buildingMid = Color(0xFFE2E0F8);

  /// Buildings, tall.
  static const buildingTall = Color(0xFFD2CCF3);

  /// Map labels. Charcoal, never pure black — pure black on a pastel ground
  /// reads as a hole punched in the map.
  static const label = Color(0xFF303036);

  // --- People ---------------------------------------------------------------

  /// The violet end of every people gradient. Pairs with the accent blue.
  static const plum = Color(0xFF7C4DFF);

  /// The lavender a marker's glow fades out into.
  static const glow = Color(0xFFB9A5F5);

  /// Start of the marker ring and cluster gradient (accent blue).
  static const markerStart = Color(0xFF4A7FE8);

  /// End of the marker ring and cluster gradient.
  static const markerEnd = plum;

  /// The current user. Distinct from [markerStart] on purpose — "you" must not
  /// look like one more dating profile on the map.
  static const you = Color(0xFF6236D8);

  /// Fill of the ring pulsing out from the current user.
  static const youPulse = Color(0xFF9B7FE8);
}
