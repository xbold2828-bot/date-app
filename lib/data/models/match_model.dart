/// A privacy-safe person card used by "liked you" and "favorites".
class LikeCard {
  final String id;
  final String? displayName;
  final int? age;
  final String? primaryPhotoUrl;
  final bool isOnline;
  final bool isVerified;

  const LikeCard({
    required this.id,
    this.displayName,
    this.age,
    this.primaryPhotoUrl,
    this.isOnline = false,
    this.isVerified = false,
  });

  factory LikeCard.fromJson(Map<String, dynamic> json) => LikeCard(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
      );

  static List<LikeCard> listFrom(dynamic items) =>
      ((items as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LikeCard.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

/// Result of `POST /likes` — whether it was a positive like and if it matched.
class LikeResult {
  final bool liked;
  final String type; // like | favorite | pass
  final bool isMatch;

  const LikeResult({
    required this.liked,
    required this.type,
    required this.isMatch,
  });

  factory LikeResult.fromJson(Map<String, dynamic> json) => LikeResult(
        liked: json['liked'] as bool? ?? false,
        type: json['type'] as String? ?? 'like',
        isMatch: json['isMatch'] as bool? ?? false,
      );
}

/// `GET /likes/liked-you` — the gated grid of people who liked me.
///
/// When [locked] is true the server returns only [total] (no identities), so the
/// UI renders the blurred grid + "Get Premium / Watch an ad" CTA.
class LikedYouPage {
  final int total;
  final bool locked;
  final String? source; // premium | free | credits | null
  final int page;
  final int limit;
  final List<LikeCard> items;

  const LikedYouPage({
    required this.total,
    required this.locked,
    this.source,
    required this.page,
    required this.limit,
    required this.items,
  });

  factory LikedYouPage.fromJson(Map<String, dynamic> json) => LikedYouPage(
        total: (json['total'] as num?)?.toInt() ?? 0,
        locked: json['locked'] as bool? ?? false,
        source: json['source'] as String?,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        items: LikeCard.listFrom(json['items']),
      );
}
