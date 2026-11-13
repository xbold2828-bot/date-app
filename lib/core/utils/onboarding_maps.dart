import '../constants/app_string.dart';

/// Backend enum values (see `api.md` "Enum value reference").
///
/// These IDs are the ONLY thing sent to the API and the only thing screens
/// store as selection state. They never change with the app language.
/// Labels are looked up separately, at build time, through AppString.

const List<String> kGenderIds = [
  'woman',
  'man',
  'non_binary',
  'trans_woman',
  'trans_man',
  'intersex',
  'self_describe',
];

/// "Other" is sent as `ask_me` so onboarding never needs custom text.
const List<String> kPronounIds = [
  'she/her',
  'he/him',
  'they/them',
  'ask_me',
];

const List<String> kIntentIds = [
  'right_now',
  'casual',
  'dating',
  'serious',
  'friends',
  'just_chatting',
  'open_to_anything',
];

const List<String> kRelationshipStatusIds = [
  'single',
  'seeing_someone',
  'open_relationship',
  'couple',
  'prefer_not_to_say',
];

// ── ID → localized label (UI only, never sent to the backend) ───────────────

/// Turns any backend slug into readable words: `open_relationship` →
/// "Open relationship". Fallback for values the app doesn't know yet.
String humanizeSlug(String slug) {
  final cleaned = slug.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return slug;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String genderLabel(String id) => switch (id) {
  'woman' => AppString.genderWoman,
  'man' => AppString.genderMan,
  'non_binary' => AppString.genderNonBinary,
  'trans_woman' => AppString.genderTransWoman,
  'trans_man' => AppString.genderTransMan,
  'intersex' => AppString.genderIntersex,
  'self_describe' => AppString.genderSelfDescribe,
  _ => humanizeSlug(id),
};

/// Label shown on the onboarding chip (`ask_me` reads "Other" there).
String pronounLabel(String id) => switch (id) {
  'she/her' => AppString.pronounSheHer,
  'he/him' => AppString.pronounHeHim,
  'they/them' => AppString.pronounTheyThem,
  'ask_me' => AppString.pronounOther,
  _ => humanizeSlug(id),
};

String intentLabel(String id) => switch (id) {
  'right_now' => AppString.filterIntentRightNow,
  'casual' => AppString.filterIntentCasual,
  'dating' => AppString.filterIntentDating,
  'serious' => AppString.filterIntentSerious,
  'friends' => AppString.filterIntentFriends,
  'just_chatting' => AppString.filterIntentJustChatting,
  'open_to_anything' => AppString.filterIntentOpenToAnything,
  _ => humanizeSlug(id),
};

String relationshipStatusLabel(String id) => switch (id) {
  'single' => AppString.statusSingle,
  'seeing_someone' => AppString.statusSeeing,
  'open_relationship' => AppString.statusOpen,
  'couple' => AppString.statusCouple,
  'prefer_not_to_say' => AppString.statusPrivate,
  _ => humanizeSlug(id),
};

// ── LEGACY: English label → value. Do NOT use for payloads or lookups. ─────
// Kept only so files I haven't seen keep compiling. These break in any
// language other than English.

const Map<String, String> kGenderValues = {
  'Woman': 'woman',
  'Man': 'man',
  'Non-binary': 'non_binary',
  'Trans woman': 'trans_woman',
  'Trans man': 'trans_man',
  'Intersex': 'intersex',
  'Self-describe': 'self_describe',
};

const Map<String, String> kPronounValues = {
  'She/Her': 'she/her',
  'He/Him': 'he/him',
  'They/Them': 'they/them',
  'Other': 'ask_me',
};

const List<MapEntry<String, String>> kIntentOptions = [
  MapEntry('Right now', 'right_now'),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Serious', 'serious'),
  MapEntry('Friends', 'friends'),
  MapEntry('Just chatting', 'just_chatting'),
  MapEntry('Open to anything', 'open_to_anything'),
];

const Map<String, String> kRelationshipStatusLabels = {
  'single': 'Single',
  'seeing_someone': 'Seeing someone',
  'open_relationship': 'Open relationship',
  'couple': 'Couple',
  'prefer_not_to_say': 'Prefer not to say',
};