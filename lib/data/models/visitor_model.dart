import '../../core/utils/json_parse_utils.dart';
import 'match_model.dart';

/// One person on `GET /profiles/me/visitors`.
///
/// [user] is a Liked-you card under the same rules: a locked one comes back
/// redacted, with no id, name or photo. What a locked visitor does carry is
/// [visitId] — the visit, not the person — which is what unlocks them.
class VisitorCard {
  final String visitId;
  final LikeCard user;

  /// Their most recent visit. Null on a locked card.
  final DateTime? visitedAt;

  const VisitorCard({
    required this.visitId,
    required this.user,
    this.visitedAt,
  });

  static const _tag = 'VisitorCard';

  bool get locked => user.locked;

  factory VisitorCard.fromJson(Map<String, dynamic> json) => VisitorCard(
    visitId: json.safeString('visitId', tag: _tag),
    user: LikeCard.fromJson(json),
    visitedAt: DateTime.tryParse(json.safeString('visitedAt', tag: _tag)),
  );
}

/// `GET /profiles/me/visitors` — who opened my profile, gated like Liked-you.
class VisitorsPage {
  /// Visitors in the last 90 days, across all pages.
  final int total;

  /// True when at least one card in [items] came back redacted.
  final bool locked;

  final String? source; // premium | null
  final int page;
  final int limit;

  /// Free reveals and credits. Null for premium.
  final LikedYouUnlockInfo? unlocks;

  final List<VisitorCard> items;

  const VisitorsPage({
    required this.total,
    required this.locked,
    this.source,
    required this.page,
    required this.limit,
    this.unlocks,
    required this.items,
  });

  static const _tag = 'VisitorsPage';

  factory VisitorsPage.fromJson(Map<String, dynamic> json) => VisitorsPage(
    total: json.safeInt('total', tag: _tag),
    locked: json.safeBool('locked', tag: _tag),
    source: json.safeStringNullable('source', tag: _tag),
    page: json.safeInt('page', fallback: 1, tag: _tag),
    limit: json.safeInt('limit', fallback: 20, tag: _tag),
    unlocks: json['unlocks'] == null
        ? null
        : LikedYouUnlockInfo.fromJson(
            Map<String, dynamic>.from(json['unlocks'] as Map),
          ),
    items: json.safeList<VisitorCard>(
      'items',
      itemParser: (item) =>
          VisitorCard.fromJson(Map<String, dynamic>.from(item as Map)),
      tag: _tag,
    ),
  );

  bool get isEmpty => total == 0 && items.isEmpty;

  /// Whether the next locked tile can be revealed without an ad: a free
  /// reveal is left, or the wallet already covers one.
  bool get canRevealWithoutAd {
    final u = unlocks;
    if (u == null) return true;
    return u.freeRemaining > 0 || u.canAffordUnlock;
  }
}
