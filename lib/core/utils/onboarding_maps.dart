/// Maps the onboarding UI's human-readable labels to the exact backend enum
/// values (see `api.md` "Enum value reference"). Keeping this in one place stops
/// the screens from sending values the API would reject (422/400).

/// Gender chip label → `gender` enum.
const Map<String, String> kGenderValues = {
  'Woman': 'woman',
  'Man': 'man',
  'Non-binary': 'non_binary',
  'Trans woman': 'trans_woman',
  'Trans man': 'trans_man',
  'Intersex': 'intersex',
  'Self-describe': 'self_describe',
};

/// Pronoun chip label → `pronouns[]` enum. "Other" maps to `ask_me` (which
/// needs no custom text) so onboarding never blocks on a missing custom value.
const Map<String, String> kPronounValues = {
  'She/Her': 'she/her',
  'He/Him': 'he/him',
  'They/Them': 'they/them',
  'Other': 'ask_me',
};

/// Real `intent` options (label → value) for the "I'm here for" step.
const List<MapEntry<String, String>> kIntentOptions = [
  MapEntry('Right now', 'right_now'),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Serious', 'serious'),
  MapEntry('Friends', 'friends'),
  MapEntry('Just chatting', 'just_chatting'),
  MapEntry('Open to anything', 'open_to_anything'),
];

/// `relationshipStatus` enum → the label used on the "My situation" step.
const Map<String, String> kRelationshipStatusLabels = {
  'single': 'Single',
  'seeing_someone': 'Seeing someone',
  'open_relationship': 'Open relationship',
  'couple': 'Couple',
  'prefer_not_to_say': 'Prefer not to say',
};

// ── Reading values back ──────────────────────────────────────────────────────
//
// Onboarding sends labels → values; every screen that *displays* somebody else
// needs the reverse. Deriving these from the maps above rather than writing a
// second set keeps the two directions from drifting.

final Map<String, String> _genderLabels = {
  for (final e in kGenderValues.entries) e.value: e.key,
};

final Map<String, String> _pronounLabels = {
  for (final e in kPronounValues.entries) e.value: e.key,
  // Onboarding offers this as "Other"; on someone else's profile it reads
  // better as the instruction it actually is.
  'ask_me': 'Ask me',
};

final Map<String, String> _intentLabels = {
  for (final e in kIntentOptions) e.value: e.key,
};

/// Turns any backend slug into something readable: `open_relationship` →
/// "Open relationship", `she/her` → "She/her".
///
/// The fallback for tag slugs that aren't in the catalogue yet, and the reason
/// a value the app has never heard of still renders as words rather than as
/// nothing.
String humanizeSlug(String slug) {
  final cleaned = slug.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return slug;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String genderLabel(String value) => _genderLabels[value] ?? humanizeSlug(value);

String pronounLabel(String value) =>
    _pronounLabels[value] ?? humanizeSlug(value);

String intentLabel(String value) => _intentLabels[value] ?? humanizeSlug(value);

String relationshipStatusLabel(String value) =>
    kRelationshipStatusLabels[value] ?? humanizeSlug(value);

/// Normalises a radius label/value to the exact backend `DistanceBand`
/// (the UI uses en-dashes; the API expects hyphens).
String? normalizeDistanceBand(String? raw) {
  if (raw == null) return null;
  final v = raw.replaceAll('–', '-').replaceAll('—', '-').trim();
  const bands = {'<2 km', '2-5 km', '5-10 km', '10 km+'};
  return bands.contains(v) ? v : null;
}
