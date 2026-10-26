import 'package:flutter/services.dart';

/// What a haptic means, rather than how hard the motor spins.
enum Haptic {
  /// A choice changed: a tab, a segment, a chip, a toggle, a picker value.
  selection,

  /// Something small was committed: a like, a send, a photo made primary.
  light,

  /// A long press opened a menu, or something snapped into place.
  medium,

  /// A big moment landed — a match.
  success,

  /// An action failed: a message that did not send, a rejected request.
  error,
}

/// The app's haptics, by meaning.
///
/// Three rules decide where these go, from Apple's audio–haptic guidance:
///
/// - **Causality.** Fire on the event that caused it — the toggle flipping,
///   the like landing — so it is obvious what the buzz was about.
/// - **Harmony.** Fire on the same frame as the visual change, never after a
///   delay. A buzz that trails the pixels reads as two separate events.
/// - **Utility.** Only where it earns its place. There is deliberately no
///   `tap()` here: a haptic on every button teaches people to ignore all of
///   them, including the ones that matter.
abstract final class AppHaptics {
  static void play(Haptic haptic) => switch (haptic) {
    Haptic.selection => selection(),
    Haptic.light => light(),
    Haptic.medium => medium(),
    Haptic.success => success(),
    Haptic.error => error(),
  };

  static void selection() => HapticFeedback.selectionClick();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  /// One strong impact. iOS's own success pattern is two taps, but faking it
  /// with a timer would leave the second tap trailing the visual — and a
  /// pending timer in every widget test that triggers it.
  static void success() => HapticFeedback.heavyImpact();

  static void error() => HapticFeedback.mediumImpact();
}
