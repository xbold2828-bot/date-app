List<String> _strs(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// A privacy-safe discovery card (`GET /discovery/nearby`). Carries a distance
/// BAND only — never coordinates.
class DiscoveryCard {
  final String id;
  final String? displayName;
  final int? age;
  final String? gender;
  final List<String> pronouns;
  final List<String> intent;
  final List<String> personalityTags;
  final String distanceBand;
  final String? city;
  final bool isOnline;
  final bool isVerified;
  final String? primaryPhotoUrl;
  final bool locked;

  const DiscoveryCard({
    required this.id,
    this.displayName,
    this.age,
    this.gender,
    this.pronouns = const [],
    this.intent = const [],
    this.personalityTags = const [],
    this.distanceBand = '',
    this.city,
    this.isOnline = false,
    this.isVerified = false,
    this.primaryPhotoUrl,
    this.locked = false,
  });

  factory DiscoveryCard.fromJson(Map<String, dynamic> json) => DiscoveryCard(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        gender: json['gender'] as String?,
        pronouns: _strs(json['pronouns']),
        intent: _strs(json['intent']),
        personalityTags: _strs(json['personalityTags']),
        distanceBand: json['distanceBand'] as String? ?? '',
        city: json['city'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        locked: json['locked'] as bool? ?? false,
      );
}

/// The `GET /discovery/nearby` response envelope (`source` records how the page
/// was unlocked: premium / free allowance / spent credits).
class NearbyPage {
  final String? city;
  final int page;
  final int limit;
  final String source;
  final List<DiscoveryCard> items;

  const NearbyPage({
    this.city,
    required this.page,
    required this.limit,
    required this.source,
    required this.items,
  });

  factory NearbyPage.fromJson(Map<String, dynamic> json) => NearbyPage(
        city: json['city'] as String?,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        source: json['source'] as String? ?? 'free',
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => DiscoveryCard.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  bool get hasMore => items.length >= limit;
}
