
import '../../core/utils/json_parse_utils.dart';

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

  static const _tag = 'LikeCard';

  factory LikeCard.fromJson(Map<String, dynamic> json) => LikeCard(
    id: json.safeString('id', tag: _tag),
    displayName: json.safeStringNullable('displayName', tag: _tag),
    age: json.safeIntNullable('age', tag: _tag),
    primaryPhotoUrl: json.safeStringNullable('primaryPhotoUrl', tag: _tag),
    isOnline: json.safeBool('isOnline', tag: _tag),
    isVerified: json.safeBool('isVerified', tag: _tag),
    distanceMeters: json.safeNumNullable('distanceMeters', tag: _tag),
    lastActiveAt: DateTime.tryParse(
      json.safeString('lastActiveAt', tag: _tag),
    ),
    locked: json.safeBool('locked', tag: _tag),
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

  static const _tag = 'LikeResult';

  factory LikeResult.fromJson(Map<String, dynamic> json) => LikeResult(
    liked: json.safeBool('liked', tag: _tag),
    type: json.safeString('type', fallback: 'like', tag: _tag),
    isMatch: json.safeBool('isMatch', tag: _tag),
    alreadyReacted: json.safeBool('alreadyReacted', tag: _tag),
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

  static const _tag = 'MutualCard';

  factory MutualCard.fromJson(Map<String, dynamic> json) => MutualCard(
    user: LikeCard.fromJson(json),
    matchedAt: DateTime.tryParse(json.safeString('matchedAt', tag: _tag)),
    conversationId: json.safeStringNullable('conversationId', tag: _tag),
  );
}

/// The `unlocks` block on `GET /likes/liked-you` — everything the CTA needs to
/// say something concrete ("Unlock for 1 credit — you have 46") instead of a
/// generic prompt. Absent or zeroed-out once nothing is locked.
class LikedYouUnlockInfo {
  /// How many free reveals this viewer gets, ever (not per day).
  final int freeTotal;

  /// How many of those free reveals have already been spent.
  final int freeUsed;

  /// Free reveals still available before credits are needed.
  final int freeRemaining;

  /// Ad-credits required to unlock the next locked card.
  final int creditCost;

  /// This viewer's current ad-credit balance.
  final int creditBalance;

  const LikedYouUnlockInfo({
    this.freeTotal = 0,
    this.freeUsed = 0,
    this.freeRemaining = 0,
    this.creditCost = 0,
    this.creditBalance = 0,
  });

  static const _tag = 'LikedYouUnlockInfo';

  factory LikedYouUnlockInfo.fromJson(Map<String, dynamic> json) =>
      LikedYouUnlockInfo(
        freeTotal: json.safeInt('freeTotal', tag: _tag),
        freeUsed: json.safeInt('freeUsed', tag: _tag),
        freeRemaining: json.safeInt('freeRemaining', tag: _tag),
        creditCost: json.safeInt('creditCost', tag: _tag),
        creditBalance: json.safeInt('creditBalance', tag: _tag),
      );

  /// Whether this viewer's balance covers the next unlock right now.
  bool get canAffordUnlock => creditBalance >= creditCost;
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

  /// Credit/free-reveal accounting for the unlock CTA. Null on a fully
  /// unlocked page — there's nothing left to spend.
  final LikedYouUnlockInfo? unlocks;

  final List<LikeCard> items;

  const LikedYouPage({
    required this.total,
    required this.locked,
    this.source,
    required this.page,
    required this.limit,
    this.freeVisible = 0,
    this.lockedCount = 0,
    this.unlocks,
    required this.items,
  });

  static const _tag = 'LikedYouPage';

  factory LikedYouPage.fromJson(Map<String, dynamic> json) => LikedYouPage(
    total: json.safeInt('total', tag: _tag),
    locked: json.safeBool('locked', tag: _tag),
    source: json.safeStringNullable('source', tag: _tag),
    page: json.safeInt('page', fallback: 1, tag: _tag),
    limit: json.safeInt('limit', fallback: 20, tag: _tag),
    freeVisible: json.safeInt('freeVisible', tag: _tag),
    lockedCount: json.safeInt('lockedCount', tag: _tag),
    unlocks: json['unlocks'] == null
        ? null
        : LikedYouUnlockInfo.fromJson(
      Map<String, dynamic>.from(json['unlocks'] as Map),
    ),
    items: json.safeList<LikeCard>(
      'items',
      itemParser: (item) =>
          LikeCard.fromJson(Map<String, dynamic>.from(item as Map)),
      tag: _tag,
    ),
  );

  /// True when there is nobody here at all — as opposed to people the viewer
  /// simply has not unlocked, which is not an empty state.
  bool get isEmpty => total == 0 && items.isEmpty;
}