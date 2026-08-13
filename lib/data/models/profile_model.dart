List<String> _strs(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// `GET /profiles/:id` — the tap-through profile popup for another user.
///
/// The adult "desires" ([preferenceTags]) are only present when the viewer is
/// verified; otherwise [desiresLocked] is true and [preferenceTags] is null.
class PublicProfile {
  final String id;
  final String? displayName;
  final int? age;
  final String? gender;
  final List<String> pronouns;
  final List<String> intent;
  final String? relationshipStatus;
  final String? bio;
  final List<String> personalityTags;
  final List<String>? preferenceTags;
  final bool desiresLocked;
  final List<String>? hardNos;
  final String? distanceBand;
  final String? city;
  final bool isOnline;
  final bool isVerified;
  final String? primaryPhotoUrl;
  final List<String> photos;

  /// Whether I have already liked this person.
  ///
  /// The like button has no other way to know: without it every profile
  /// rendered as un-liked on reopen, which invited people to like the same
  /// person again and again.
  final bool hasLiked;

  /// We liked each other. Implies [hasLiked].
  final bool isMatch;

  const PublicProfile({
    required this.id,
    this.displayName,
    this.age,
    this.gender,
    this.pronouns = const [],
    this.intent = const [],
    this.relationshipStatus,
    this.bio,
    this.personalityTags = const [],
    this.preferenceTags,
    this.desiresLocked = true,
    this.hardNos,
    this.distanceBand,
    this.city,
    this.isOnline = false,
    this.isVerified = false,
    this.primaryPhotoUrl,
    this.photos = const [],
    this.hasLiked = false,
    this.isMatch = false,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        gender: json['gender'] as String?,
        pronouns: _strs(json['pronouns']),
        intent: _strs(json['intent']),
        relationshipStatus: json['relationshipStatus'] as String?,
        bio: json['bio'] as String?,
        personalityTags: _strs(json['personalityTags']),
        preferenceTags:
            json['preferenceTags'] == null ? null : _strs(json['preferenceTags']),
        desiresLocked: json['desiresLocked'] as bool? ?? true,
        hardNos: json['hardNos'] == null ? null : _strs(json['hardNos']),
        distanceBand: json['distanceBand'] as String?,
        city: json['city'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        photos: _strs(json['photos']),
        hasLiked: json['hasLiked'] as bool? ?? false,
        isMatch: json['isMatch'] as bool? ?? false,
      );
}
