/// Backend `TagCategory` values. Onboarding must send curated slugs — the API
/// rejects anything not in the catalogue — so screens render from these.
///
/// Lives in `core/constants` rather than beside the providers because the
/// selection caps in [SelectionLimits] are keyed by category, and a constant
/// that both the limits and the screens depend on cannot sit downstream of
/// either.
///
/// The keys are storage identifiers and match the server's enum, so they are
/// deliberately unchanged even where the heading above them no longer matches:
/// `role_energy` heads "Your energy", `fantasy_setting` heads "Your kind of
/// date". Renaming them would mean rewriting every profile already saved.
class TagCategories {
  TagCategories._();

  static const String personality = 'personality';
  static const String roleEnergy = 'role_energy';
  static const String into = 'into';
  static const String scenario = 'scenario';
  static const String intensity = 'intensity';
  static const String experience = 'experience';
  static const String fantasySetting = 'fantasy_setting';
  static const String hardNo = 'hard_no';

  /// The categories that make up the step-6 "Define your vibe" screen, in
  /// display order.
  static const List<String> preferences = [
    roleEnergy,
    into,
    scenario,
    intensity,
    experience,
    fantasySetting,
  ];

  /// How each category reads in the interface.
  ///
  /// The funnel, the filter sheet and the "Me" editor all render these same
  /// groups, so the wording lives here rather than in three private maps that
  /// drift apart the first time one of them is renamed.
  ///
  /// Every heading describes *how someone connects*, not what they do sexually.
  /// "Role & energy", "Into", "Scenario", "Intensity" and "Fantasy & setting"
  /// were the previous names; each one classified the app as sex-dating on its
  /// own, before a single tag underneath it was read.
  static const Map<String, String> labels = {
    personality: 'Atmosphere',
    roleEnergy: 'Your energy',
    into: "What you're drawn to",
    scenario: "What you're looking for",
    intensity: 'Your pace',
    experience: 'Dating experience',
    fantasySetting: 'Your kind of date',
    hardNo: "Hard no's",
  };

  /// The heading for a category, falling back to the raw slug so a category
  /// the server adds before the app knows about it still renders as something.
  static String label(String category) => labels[category] ?? category;
}
