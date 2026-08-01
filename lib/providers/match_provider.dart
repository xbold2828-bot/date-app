import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../data/models/discovery_user_model.dart';
import '../data/models/entitlements_model.dart';
import '../data/models/match_model.dart';
import '../data/models/paginated.dart';
import 'core_providers.dart';

/// Active discovery filters (the All / Casual / Dating / Right-now tabs + the
/// premium verified/online toggles).
class DiscoveryFilter {
  final String? intent; // null = All
  final String? band;
  final bool verifiedOnly;
  final bool onlineOnly;

  const DiscoveryFilter({
    this.intent,
    this.band,
    this.verifiedOnly = false,
    this.onlineOnly = false,
  });

  DiscoveryFilter copyWith({
    String? intent,
    bool clearIntent = false,
    String? band,
    bool clearBand = false,
    bool? verifiedOnly,
    bool? onlineOnly,
  }) =>
      DiscoveryFilter(
        intent: clearIntent ? null : (intent ?? this.intent),
        band: clearBand ? null : (band ?? this.band),
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        onlineOnly: onlineOnly ?? this.onlineOnly,
      );
}

final discoveryFilterProvider =
    StateProvider<DiscoveryFilter>((ref) => const DiscoveryFilter());

/// The nearby feed with pagination + gate handling. When the server refuses a
/// page (402), [paywall] is set and the UI renders the unlock CTA instead of
/// throwing; when no location is set (400), [needsLocation] is true.
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
        band: filter.band,
        verifiedOnly: filter.verifiedOnly,
        onlineOnly: filter.onlineOnly,
      );
      final items = page == 1
          ? res.items
          : [...?previous?.items, ...res.items];
      return NearbyState(
        items: items,
        city: res.city ?? previous?.city,
        page: res.page,
        hasMore: res.hasMore,
      );
    } on EntitlementRequiredException catch (e) {
      // Out of allowance/credits — keep what we have, surface the paywall.
      return (previous ?? const NearbyState()).copyWith(
        paywall: e,
        loadingMore: false,
      );
    } on BadRequestException {
      return (previous ?? const NearbyState())
          .copyWith(needsLocation: true, loadingMore: false);
    }
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

/// Premium status + credits + free daily allowances (the "Discovery Limit" UI).
final entitlementsProvider = FutureProvider.autoDispose<Entitlements>(
  (ref) => ref.watch(discoveryRepositoryProvider).entitlements(),
);

/// "Liked you" — gated grid.
final likedYouProvider = FutureProvider.autoDispose<LikedYouPage>(
  (ref) => ref.watch(matchRepositoryProvider).likedYou(),
);

/// People I favourited.
final favoritesProvider =
    FutureProvider.autoDispose<PageResult<LikeCard>>(
  (ref) => ref.watch(matchRepositoryProvider).favorites(),
);

/// Imperative like/favorite/pass actions. Returns the [LikeResult] (so callers
/// can celebrate a match), then callers can invalidate the feeds.
class LikeActions {
  LikeActions(this.ref);
  final Ref ref;

  Future<LikeResult> react(String toUserId, String type) =>
      ref.read(matchRepositoryProvider).react(toUserId, type);

  Future<void> unreact(String userId) =>
      ref.read(matchRepositoryProvider).unreact(userId);
}

final likeActionsProvider = Provider<LikeActions>((ref) => LikeActions(ref));
