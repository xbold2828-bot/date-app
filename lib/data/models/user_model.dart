import 'location_sharing_model.dart';

export 'location_sharing_model.dart' show LocationAudience, LocationSharing;

/// Helpers shared by the model layer.
List<String> _stringList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// Premium status block on the self-view.
class Premium {
  final bool isActive;
  final String? plan;
  final DateTime? until;

  const Premium({required this.isActive, this.plan, this.until});

  factory Premium.fromJson(Map<String, dynamic> json) => Premium(
        isActive: json['isActive'] as bool? ?? false,
        plan: json['plan'] as String?,
        until: DateTime.tryParse(json['until'] as String? ?? ''),
      );
}

/// The editable profile block on the self-view.
class MeProfile {
  final String? displayName;
  final String? bio;
  final String? gender;
  final String? genderSelfDescribe;
  final List<String> pronouns;
  final String? pronounsCustom;
  final List<String> showMe;
  final List<String> intent;
  final String? relationshipStatus;
  final List<String> personalityTags;
  final List<String> preferenceTags;
  final List<String> hardNos;
  final bool showHardNosOnProfile;

  const MeProfile({
    this.displayName,
    this.bio,
    this.gender,
    this.genderSelfDescribe,
    this.pronouns = const [],
    this.pronounsCustom,
    this.showMe = const [],
    this.intent = const [],
    this.relationshipStatus,
    this.personalityTags = const [],
    this.preferenceTags = const [],
    this.hardNos = const [],
    this.showHardNosOnProfile = true,
  });

  factory MeProfile.fromJson(Map<String, dynamic> json) => MeProfile(
        displayName: json['displayName'] as String?,
        bio: json['bio'] as String?,
        gender: json['gender'] as String?,
        genderSelfDescribe: json['genderSelfDescribe'] as String?,
        pronouns: _stringList(json['pronouns']),
        pronounsCustom: json['pronounsCustom'] as String?,
        showMe: _stringList(json['showMe']),
        intent: _stringList(json['intent']),
        relationshipStatus: json['relationshipStatus'] as String?,
        personalityTags: _stringList(json['personalityTags']),
        preferenceTags: _stringList(json['preferenceTags']),
        hardNos: _stringList(json['hardNos']),
        showHardNosOnProfile: json['showHardNosOnProfile'] as bool? ?? true,
      );
}

/// The owner's own location summary (never raw coordinates of others).
class MeLocation {
  final String? city;
  final String? preferredBand;
  final DateTime? updatedAt;

  /// The exact point I submitted — **my own coordinates, and nobody else's**.
  ///
  /// This is the anchor every "nearby" query of mine is measured from, which is
  /// the only reason the client is told it. The Explore map draws "you are
  /// here" from this rather than from the device's live GPS: sourcing it from
  /// the device meant the map drew me in one place while the server ranked
  /// everyone by distance from another, so a stale anchor rendered as a screen
  /// full of people standing in the wrong streets.
  ///
  /// Null on an account that has never completed the location step.
  final double? latitude;
  final double? longitude;

  const MeLocation({
    this.city,
    this.preferredBand,
    this.updatedAt,
    this.latitude,
    this.longitude,
  });

  /// True once there is a point for discovery to measure from.
  bool get hasPoint => latitude != null && longitude != null;

  factory MeLocation.fromJson(Map<String, dynamic> json) => MeLocation(
        city: json['city'] as String?,
        preferredBand: json['preferredBand'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

/// Onboarding funnel progress (also returned standalone by
/// `GET /onboarding/status`).
class OnboardingProgress {
  final List<String> completedSteps;
  final bool isComplete;
  final String? nextStep;
  final double progress; // 0..1

  /// The photo step finished without an upload — worth nudging about later.
  final bool photoSkipped;

  const OnboardingProgress({
    this.completedSteps = const [],
    this.isComplete = false,
    this.nextStep,
    this.progress = 0,
    this.photoSkipped = false,
  });

  bool hasCompleted(String step) => completedSteps.contains(step);

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) =>
      OnboardingProgress(
        completedSteps: _stringList(json['completedSteps']),
        isComplete: json['isComplete'] as bool? ?? false,
        nextStep: json['nextStep'] as String?,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        photoSkipped: json['photoSkipped'] as bool? ?? false,
      );
}

/// The backend's `OnboardingStep` values, in canonical funnel order. Used to
/// resume the funnel at `onboarding.nextStep` after a refresh.
class OnboardingSteps {
  OnboardingSteps._();

  static const String ageVerification = 'age_verification';
  static const String basics = 'basics';
  static const String intent = 'intent';
  static const String status = 'status';
  static const String personality = 'personality';
  static const String preferences = 'preferences';
  static const String hardNos = 'hard_nos';
  static const String photo = 'photo';
  static const String location = 'location';
  static const String agreement = 'agreement';
}

/// The full self-view from `GET /users/me` and every onboarding step response.
class MeUser {
  final String id;
  final String supabaseId;
  final String? email;
  final String? phone;
  final String status;

  /// Which of my media is the profile photo, so the gallery can badge it and
  /// offer "make this my profile photo" on the rest.
  final String? primaryPhotoId;
  final String? dob;
  final int? age;
  final bool ageVerified;
  final bool hasVerifiedSelfie;
  final bool verified;
  final String verificationStatus;
  final Premium premium;
  final MeProfile profile;
  final MeLocation? location;

  /// Who can see me on the Explore map. Rides along on every self-view so the
  /// "Me" tab can state the current setting without a second request.
  final LocationSharing locationSharing;

  final OnboardingProgress onboarding;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  const MeUser({
    required this.id,
    required this.supabaseId,
    this.email,
    this.phone,
    required this.status,
    this.primaryPhotoId,
    this.dob,
    this.age,
    this.ageVerified = false,
    this.hasVerifiedSelfie = false,
    this.verified = false,
    this.verificationStatus = 'none',
    required this.premium,
    required this.profile,
    this.location,
    this.locationSharing = LocationSharing.initial,
    required this.onboarding,
    this.createdAt,
    this.lastActiveAt,
  });

  bool get isOnboardingComplete => onboarding.isComplete;
  String? get displayName => profile.displayName;

  factory MeUser.fromJson(Map<String, dynamic> json) => MeUser(
        id: json['id'] as String? ?? '',
        supabaseId: json['supabaseId'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'active',
        primaryPhotoId: json['primaryPhotoId'] as String?,
        dob: json['dob'] as String?,
        age: (json['age'] as num?)?.toInt(),
        ageVerified: json['ageVerified'] as bool? ?? false,
        hasVerifiedSelfie: json['hasVerifiedSelfie'] as bool? ?? false,
        verified: json['verified'] as bool? ?? false,
        verificationStatus: json['verificationStatus'] as String? ?? 'none',
        premium: Premium.fromJson(
          Map<String, dynamic>.from(json['premium'] as Map? ?? const {}),
        ),
        profile: MeProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
        ),
        location: json['location'] == null
            ? null
            : MeLocation.fromJson(
                Map<String, dynamic>.from(json['location'] as Map),
              ),
        locationSharing: json['locationSharing'] == null
            ? LocationSharing.initial
            : LocationSharing.fromJson(
                Map<String, dynamic>.from(json['locationSharing'] as Map),
              ),
        onboarding: OnboardingProgress.fromJson(
          Map<String, dynamic>.from(json['onboarding'] as Map? ?? const {}),
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
      );
}
