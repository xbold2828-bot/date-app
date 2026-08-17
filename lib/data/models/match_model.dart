/// A privacy-safe person card used by "liked you" and "favorites".
class LikeCard {
  final String id;
  final String? displayName;
  final int? age;
  final String? primaryPhotoUrl;
  final bool isOnline;
  final bool isVerified;

  /// How far away they are, in metres, rounded server-side. Null when either
  /// side has no stored location — and always null on a locked card, because
  /// the redaction drops it rather than the UI hiding it.
  final num? distanceMeters;

  /// When they were last seen. Null when unknown, and on locked cards.
  final DateTime? lastActiveAt;

  /// This person was redacted server-side: the response carries no name, no
  /// photo, no age — and no [id], so there is nothing to tap through to. The
  /// blur in the grid is decoration over an already-empty card, not the thing
  /// keeping the identity back.
  final bool locked;

  const LikeCard({
    required this.id,
    this.displayName,
    this.age,
    this.primaryPhotoUrl,
    this.isOnline = false,
    this.isVerified = false,
    this.distanceMeters,
    this.lastActiveAt,
    this.locked = false,
  });

  factory LikeCard.fromJson(Map<String, dynamic> json) => LikeCard(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        distanceMeters: json['distanceMeters'] as num?,
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
        locked: json['locked'] as bool? ?? false,
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

  /// This reaction was already on record — the server did nothing.
  final bool alreadyReacted;

  /// The person just matched with.
  ///
  /// Present only on the reaction that CREATED the match, never on a repeat.
  /// That is what stops the celebration replaying on every tap.
  final LikeCard? match;

  const LikeResult({
    required this.liked,
    required this.type,
    required this.isMatch,
    this.alreadyReacted = false,
    this.match,
  });

  factory LikeResult.fromJson(Map<String, dynamic> json) => LikeResult(
        liked: json['liked'] as bool? ?? false,
        type: json['type'] as String? ?? 'like',
        isMatch: json['isMatch'] as bool? ?? false,
        alreadyReacted: json['alreadyReacted'] as bool? ?? false,
        match: json['match'] == null
            ? null
            : LikeCard.fromJson(
                Map<String, dynamic>.from(json['match'] as Map),
              ),
      );
}

/// `GET /likes/mutual` — a match.
///
/// Always complete: no `locked`, no redaction, no paywall. Both people chose
/// this, so there is nothing left to sell them.
class MutualCard {
  final LikeCard user;
  final DateTime? matchedAt;

  /// Set when a thread already exists, so the card opens it instead of starting
  /// a new one.
  final String? conversationId;

  const MutualCard({
    required this.user,
    this.matchedAt,
    this.conversationId,
  });

  factory MutualCard.fromJson(Map<String, dynamic> json) => MutualCard(
        user: LikeCard.fromJson(json),
        matchedAt: DateTime.tryParse(json['matchedAt'] as String? ?? ''),
        conversationId: json['conversationId'] as String?,
      );
}

/// `GET /likes/liked-you` — the freemium grid of people who liked me.
///
/// A free member always sees the first [freeVisible] people in full; everyone
/// after them arrives already redacted (`LikeCard.locked`), with [lockedCount]
/// saying how many are still hidden. Premium or an ad-credit unlock returns the
/// whole feed intact, [locked] false and [lockedCount] zero.
class LikedYouPage {
  final int total;

  /// True when at least one card in [items] came back redacted.
  final bool locked;

  final String? source; // premium | free | credits | null
  final int page;
  final int limit;

  /// How many profiles the free preview shows in full. Zero once unlocked.
  final int freeVisible;

  /// People across the whole feed still hidden from this viewer. This is the
  /// number on the "unlock" CTA.
  final int lockedCount;

  final List<LikeCard> items;

  const LikedYouPage({
    required this.total,
    required this.locked,
    this.source,
    required this.page,
    required this.limit,
    this.freeVisible = 0,
    this.lockedCount = 0,
    required this.items,
  });

  factory LikedYouPage.fromJson(Map<String, dynamic> json) => LikedYouPage(
        total: (json['total'] as num?)?.toInt() ?? 0,
        locked: json['locked'] as bool? ?? false,
        source: json['source'] as String?,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        freeVisible: (json['freeVisible'] as num?)?.toInt() ?? 0,
        lockedCount: (json['lockedCount'] as num?)?.toInt() ?? 0,
        items: LikeCard.listFrom(json['items']),
      );

  /// True when there is nobody here at all — as opposed to people the viewer
  /// simply has not unlocked, which is not an empty state.
  bool get isEmpty => total == 0 && items.isEmpty;
}
