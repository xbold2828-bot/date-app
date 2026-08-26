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

  /// How far away they are, in metres, rounded server-side.
  ///
  /// The band above is still here and still used — the Explore strip speaks
  /// bands, and a viewer with no location of their own gets neither. Cards
  /// print this when it is there and fall back to the band when it is not,
  /// which is also what happens against a server that predates the field.
  ///
  /// Null on a locked card by design: the server drops it rather than the UI
  /// hiding it, so a blurred stranger cannot be placed.
  final num? distanceMeters;

  final String? city;
  final bool isOnline;

  /// When they were last seen. Null when unknown, and on locked cards.
  final DateTime? lastActiveAt;

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
    this.distanceMeters,
    this.city,
    this.isOnline = false,
    this.lastActiveAt,
    this.isVerified = false,
    this.primaryPhotoUrl,
    this.locked = false,
  });

  /// Only [isOnline] is overridable, and only because presence is the one
  /// field with a live source of its own: the `/presence` socket knows sooner
  /// than the fetch that produced this card did. Everything else on a card is
  /// the server's answer, and a client-side edit of it would be a lie.
  DiscoveryCard withOnline(bool online) => DiscoveryCard(
        id: id,
        displayName: displayName,
        age: age,
        gender: gender,
        pronouns: pronouns,
        intent: intent,
        personalityTags: personalityTags,
        distanceBand: distanceBand,
        distanceMeters: distanceMeters,
        city: city,
        isOnline: online,
        lastActiveAt: lastActiveAt,
        isVerified: isVerified,
        primaryPhotoUrl: primaryPhotoUrl,
        locked: locked,
      );

  factory DiscoveryCard.fromJson(Map<String, dynamic> json) => DiscoveryCard(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        gender: json['gender'] as String?,
        pronouns: _strs(json['pronouns']),
        intent: _strs(json['intent']),
        personalityTags: _strs(json['personalityTags']),
        distanceBand: json['distanceBand'] as String? ?? '',
        distanceMeters: json['distanceMeters'] as num?,
        city: json['city'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
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

  /// How many people are behind the current filters in total, ranked. The
  /// server caps this at its candidate pool, so it is what the feed will
  /// actually hand over rather than what the database matched.
  final int total;

  /// The server's own answer about whether another page exists.
  ///
  /// Inferred from `items.length >= limit` before the API returned it, which
  /// was wrong in exactly one place and it was the place people noticed: a
  /// final page that happened to be full showed "Show more people", and
  /// tapping it produced nothing.
  final bool hasMore;

  final String source;
  final List<DiscoveryCard> items;

  const NearbyPage({
    this.city,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    required this.source,
    required this.items,
  });

  factory NearbyPage.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final limit = (json['limit'] as num?)?.toInt() ?? 30;
    final items = ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DiscoveryCard.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return NearbyPage(
      city: json['city'] as String?,
      page: page,
      limit: limit,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      // Falls back to the old inference so the app still pages against a
      // server that predates the field.
      hasMore: json['hasMore'] as bool? ?? items.length >= limit,
      source: json['source'] as String? ?? 'free',
      items: items,
    );
  }
}
