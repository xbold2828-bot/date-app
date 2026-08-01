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

/// Normalises a radius label/value to the exact backend `DistanceBand`
/// (the UI uses en-dashes; the API expects hyphens).
String? normalizeDistanceBand(String? raw) {
  if (raw == null) return null;
  final v = raw.replaceAll('–', '-').replaceAll('—', '-').trim();
  const bands = {'<2 km', '2-5 km', '5-10 km', '10 km+'};
  return bands.contains(v) ? v : null;
}
