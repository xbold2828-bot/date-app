import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/repositories/ads_repository.dart';
import '../../../../data/models/discovery_user_model.dart';
import '../../../../data/models/entitlements_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/paginated.dart';
import '../../models/unlike_result_model.dart';
import '../../../../providers/core_providers.dart';
import '../like_quota_provider/like_quota_provider.dart';

/// The lowest and highest ages the range slider offers. [kAgeFilterMax] is the
/// "and above" notch — the backend drops the upper bound at that value.
const int kAgeFilterMin = 18;
const int kAgeFilterMax = 60;

/// Active discovery filters: the intent chips plus everything in the filter
/// sheet. Free members get show-me / age / intent; the rest is premium and the
/// API rejects it (403) for everyone else.
class DiscoveryFilter {
  final String? intent; // null = All
  final List<String> genders;
  final int minAge;
  final int maxAge;

  // Premium.
  final bool verifiedOnly;
  final bool onlineOnly;
  final bool recentlyActive;
  final List<String> relationshipStatus;
  final List<String> personalityTags;
  final List<String> preferenceTags;

  const DiscoveryFilter({
    this.intent,
    this.genders = const [],
    this.minAge = kAgeFilterMin,
    this.maxAge = kAgeFilterMax,
    this.verifiedOnly = false,
    this.onlineOnly = false,
    this.recentlyActive = false,
    this.relationshipStatus = const [],
    this.personalityTags = const [],
    this.preferenceTags = const [],
  });

  /// True when the age slider is untouched, so it can be left off the request.
  bool get isFullAgeRange =>
      minAge <= kAgeFilterMin && maxAge >= kAgeFilterMax;

  /// Whether any premium-only filter is active.
  bool get usesPremiumFilters =>
      verifiedOnly ||
          onlineOnly ||
          recentlyActive ||
          relationshipStatus.isNotEmpty ||
          personalityTags.isNotEmpty ||
          preferenceTags.isNotEmpty;

  /// Everything except the intent chips, which live outside the sheet.
  DiscoveryFilter clearedToDefaults() => DiscoveryFilter(intent: intent);

  /// Drops premium-only selections, so a lapsed member's saved filters don't
  /// turn every request into a 403.
  DiscoveryFilter withoutPremium() => DiscoveryFilter(
    intent: intent,
    genders: genders,
    minAge: minAge,
    maxAge: maxAge,
  );

  DiscoveryFilter copyWith({
    String? intent,
    bool clearIntent = false,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) =>
      DiscoveryFilter(
        intent: clearIntent ? null : (intent ?? this.intent),
        genders: genders ?? this.genders,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        onlineOnly: onlineOnly ?? this.onlineOnly,
        recentlyActive: recentlyActive ?? this.recentlyActive,
        relationshipStatus: relationshipStatus ?? this.relationshipStatus,
        personalityTags: personalityTags ?? this.personalityTags,
        preferenceTags: preferenceTags ?? this.preferenceTags,
      );

  // Value equality matters: [nearbyCountProvider] is keyed on this object, so
  // without it every rebuild would fire another count request.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DiscoveryFilter &&
              other.intent == intent &&
              listEquals(other.genders, genders) &&
              other.minAge == minAge &&
              other.maxAge == maxAge &&
              other.verifiedOnly == verifiedOnly &&
              other.onlineOnly == onlineOnly &&
              other.recentlyActive == recentlyActive &&
              listEquals(other.relationshipStatus, relationshipStatus) &&
              listEquals(other.personalityTags, personalityTags) &&
              listEquals(other.preferenceTags, preferenceTags);

  @override
  int get hashCode => Object.hash(
    intent,
    Object.hashAll(genders),
    minAge,
    maxAge,
    verifiedOnly,
    onlineOnly,
    recentlyActive,
    Object.hashAll(relationshipStatus),
    Object.hashAll(personalityTags),
    Object.hashAll(preferenceTags),
  );
}

final discoveryFilterProvider =
StateProvider<DiscoveryFilter>((ref) => const DiscoveryFilter());

/// Live match count for a draft filter set — the number on the filter sheet's
/// "Show N people" button.
final nearbyCountProvider =
FutureProvider.autoDispose.family<int, DiscoveryFilter>((ref, filter) {
  return ref.watch(discoveryRepositoryProvider).nearbyCount(
    intent: filter.intent,
    genders: filter.genders,
    minAge: filter.isFullAgeRange ? null : filter.minAge,
    maxAge: filter.isFullAgeRange ? null : filter.maxAge,
    verifiedOnly: filter.verifiedOnly,
    onlineOnly: filter.onlineOnly,
    recentlyActive: filter.recentlyActive,
    relationshipStatus: filter.relationshipStatus,
    personalityTags: filter.personalityTags,
    preferenceTags: filter.preferenceTags,
  );
});

/// The nearby feed with pagination and gate handling. When the server refuses
/// a page (402), [paywall] is set and the UI shows the unlock card; when no
/// location is set (400), [needsLocation] is true.
class NearbyState {
  final List<DiscoveryCard> items;
  final String? city;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final EntitlementRequiredException? paywall;
  final bool needsLocation;

  const NearbyState({
    this.items = const [],
    this.city,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.paywall,
    this.needsLocation = false,
  });

  NearbyState copyWith({
    List<DiscoveryCard>? items,
    String? city,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    EntitlementRequiredException? paywall,
    bool clearPaywall = false,
    bool? needsLocation,
  }) =>
      NearbyState(
        items: items ?? this.items,
        city: city ?? this.city,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        paywall: clearPaywall ? null : (paywall ?? this.paywall),
        needsLocation: needsLocation ?? this.needsLocation,
      );
}

class NearbyNotifier extends AsyncNotifier<NearbyState> {
  @override
  Future<NearbyState> build() {
    ref.watch(discoveryFilterProvider); // reload when filters change
    return _load(page: 1);
  }

  Future<NearbyState> _load({required int page, NearbyState? previous}) async {
    final filter = ref.read(discoveryFilterProvider);
    final repo = ref.read(discoveryRepositoryProvider);
    try {
      final res = await repo.nearby(
        page: page,
        intent: filter.intent,
        genders: filter.genders,
        minAge: filter.isFullAgeRange ? null : filter.minAge,
        maxAge: filter.isFullAgeRange ? null : filter.maxAge,
        verifiedOnly: filter.verifiedOnly,
        onlineOnly: filter.onlineOnly,
        recentlyActive: filter.recentlyActive,
        relationshipStatus: filter.relationshipStatus,
        preferenceTags: filter.preferenceTags,
      );
      final items = page == 1
          ? res.items
          : _appendNew(previous?.items ?? const [], res.items);
      return NearbyState(
        items: items,
        city: res.city ?? previous?.city,
        page: res.page,
        hasMore: res.hasMore,
      );
    } on EntitlementRequiredException catch (e) {
      // Out of allowance or credits: keep what we have and show the paywall.
      return (previous ?? const NearbyState()).copyWith(
        paywall: e,
        loadingMore: false,
      );
    } on BadRequestException {
      return (previous ?? const NearbyState())
          .copyWith(needsLocation: true, loadingMore: false);
    }
  }

  /// Appends a page, skipping anyone already on screen. Pages can overlap when
  /// the server's ranking expires mid-scroll, and the grid can't show
  /// duplicate ids.
  static List<DiscoveryCard> _appendNew(
      List<DiscoveryCard> existing,
      List<DiscoveryCard> incoming,
      ) {
    final seen = {for (final card in existing) card.id};
    return [
      ...existing,
      ...incoming.where((card) => seen.add(card.id)),
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading<NearbyState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    state = AsyncData(await _load(page: current.page + 1, previous: current));
  }
}

final nearbyProvider =
AsyncNotifierProvider<NearbyNotifier, NearbyState>(NearbyNotifier.new);

/// Premium status, credits and the free daily allowances.
final entitlementsProvider = FutureProvider.autoDispose<Entitlements>(
      (ref) => ref.watch(discoveryRepositoryProvider).entitlements(),
);

/// "Liked you" — the gated grid.
final likedYouProvider = FutureProvider.autoDispose<LikedYouPage>(
      (ref) => ref.watch(matchRepositoryProvider).likedYou(),
);

/// Matches — the Mutual tab. Never gated, so it either loads or fails.
final mutualLikesProvider =
FutureProvider.autoDispose<PageResult<MutualCard>>(
      (ref) => ref.watch(matchRepositoryProvider).mutual(),
);

/// People I favourited.
final favoritesProvider =
FutureProvider.autoDispose<PageResult<LikeCard>>(
      (ref) => ref.watch(matchRepositoryProvider).favorites(),
);

/// The match waiting to be celebrated. Set from my own like response and from
/// the `match:new` socket event, and shown by an overlay at the top of the app.
class MatchCelebration {
  const MatchCelebration({required this.user, this.conversationId});

  final LikeCard user;
  final String? conversationId;
}

class MatchCelebrationNotifier extends Notifier<MatchCelebration?> {
  @override
  MatchCelebration? build() => null;

  void show(LikeCard user, {String? conversationId}) {
    // A card without an id came from a redacted payload; skip it.
    if (user.id.isEmpty) return;
    state = MatchCelebration(user: user, conversationId: conversationId);
  }

  void dismiss() => state = null;
}

final matchCelebrationProvider =
NotifierProvider<MatchCelebrationNotifier, MatchCelebration?>(
  MatchCelebrationNotifier.new,
);

/// Like / favorite / pass actions. After each change the like quota is
/// re-fetched, so the meter always shows what the server says.
class LikeActions {
  LikeActions(this.ref);
  final Ref ref;

  Future<LikeResult> react(String toUserId, String type) async {
    final result = await ref.read(matchRepositoryProvider).react(toUserId, type);
    ref.read(likeQuotaProvider.notifier).refresh();
    return result;
  }

  Future<void> unreact(String userId) async {
    await ref.read(matchRepositoryProvider).unreact(userId);
    ref.read(likeQuotaProvider.notifier).refresh();
  }

  /// Undoes a like/favorite/pass. Also returns the recalculated quota and
  /// whether the removed reaction had been a match.
  Future<UnlikeResult> unlike(String userId) async {
    final result = await ref.read(matchRepositoryProvider).unlike(userId);
    ref.read(likeQuotaProvider.notifier).refresh();
    return result;
  }
}

final likeActionsProvider = Provider<LikeActions>((ref) => LikeActions(ref));

/// Watching a rewarded ad to unlock something. The ad mints credits, so every
/// feed that spends them is re-fetched afterwards, including the like quota.
class AdActions {
  AdActions(this.ref);
  final Ref ref;

  /// Claims one rewarded view and refreshes whatever it may have unlocked.
  /// Returns the credits granted — zero when the view was a replay.
  Future<int> watchToUnlock({String? placement}) async {
    final reward = await ref.read(adsRepositoryProvider).claimReward(
      idempotencyKey: AdsRepository.newIdempotencyKey(),
      placement: placement,
    );
    ref.invalidate(entitlementsProvider);
    ref.invalidate(likedYouProvider);
    ref.read(nearbyProvider.notifier).refresh();
    ref.read(likeQuotaProvider.notifier).refresh();
    return reward.creditsAwarded;
  }

  /// Spends credits to reveal one specific "liked you" card, using the tapped
  /// card's [userId]. Returns the server's message and whether it succeeded.
  Future<(String, bool)> unlockLikedYou(
      String userId, {
        String? placement,
      }) async {
    final (message, success) =
    await ref.read(matchRepositoryProvider).unlockLikedYou(userId);

    if (success) {
      ref.invalidate(likedYouProvider);
      ref.read(likeQuotaProvider.notifier).refresh();
    }

    return (message, success);
  }
}

final adActionsProvider = Provider<AdActions>((ref) => AdActions(ref));