import 'tag_categories.dart';

/// How many things a person may pick, per onboarding question.
///
/// One place, because the same four questions are answered twice: once in the
/// funnel and again from the "Me" tab's editor. Before this, the funnel had no
/// caps at all and the editor did not exist — so a profile could carry fifteen
/// vibes and forty desires, and the profile view rendered every one of them.
///
/// The backend's own `ArrayMaxSize` bounds are deliberately looser (15 vibes,
/// 40 desires). These are the *product* limits and they are enforced on the
/// client; a request that slips past them is still valid to the API, which is
/// why nothing here can be relied on as a security boundary.
class SelectionLimits {
  const SelectionLimits._();

  /// "Here for" — the current intent. Exactly one.
  static const int intent = 1;

  /// "My situation" — relationship status. Exactly one.
  static const int situation = 1;

  /// "Your atmosphere" — personality tags.
  static const int vibes = 3;

  /// "Into" — the desires step, capped **per category** rather than as one
  /// budget across the step.
  ///
  /// A single pooled cap made the six groups compete: three picks spent on
  /// role & energy left nothing for scenario or fantasy, so most people
  /// answered the first section and none of the rest. Each group now carries
  /// its own allowance.
  ///
  /// Experience is the exception at one. It is a fact about you rather than a
  /// preference — "new & curious" and "very experienced" cannot both be true —
  /// so it reads as a single answer, and picking a second swaps rather than
  /// refuses (see `applySelectionLimit`).
  static const Map<String, int> intoByCategory = {
    TagCategories.roleEnergy: 3,
    TagCategories.into: 3,
    TagCategories.scenario: 3,
    TagCategories.intensity: 3,
    TagCategories.experience: 1,
    TagCategories.fantasySetting: 3,
  };

  /// The cap for one desires category. Three is the fallback, so a category
  /// added to the server's catalogue before it is listed here still behaves
  /// like the rest instead of becoming unlimited.
  static int intoIn(String category) => intoByCategory[category] ?? 3;

  /// Hard no's are boundaries, not preferences. Never capped.
  static const int? hardNos = null;
}

/// "Pick up to 3" — the hint shown under a capped question.
String selectionHint(int max) =>
    max == 1 ? 'Pick 1' : 'Pick up to $max';

/// "You can pick 3 vibes. Tap one to swap it out." — what a person sees when
/// they reach for a fourth.
String selectionLimitMessage(String noun, int max) => max == 1
    ? 'Pick just one $noun. Tap a different one to change your answer.'
    : 'You can pick $max $noun. Tap a selected one to swap it out.';
