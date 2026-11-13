import 'dart:async';
import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/extensions/global_back_extension.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ads/app_open/app_open_ad_provider.dart';
import '../../../core/ads/banner/banner_ad_widget.dart';
import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/static_assets/app_vectors.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/notification/push_deep_link.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/core_providers.dart';
import '../models/profile_seed.dart';
import '../providers/match_provider/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../common/widgets/widgets.dart';
import '../../explore/screens/explore_screen.dart';
import '../../notifications/viewmodel/providers/notification_provider/notification_provider.dart';
import '../models/like_quota_model.dart';
import '../providers/like_quota_provider/like_quota_provider.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/likes_meter.dart';
import '../widgets/match_celebration.dart';
import '../widgets/premium_filter_prompt.dart';
import './chat_detail_screen.dart';
import './profile_detail_sheet.dart';
import './request_screen.dart';
import './favourites_screen.dart';
import './you_screen.dart';
import './premium_screen.dart';

// ============================================================================
// Shared helpers
// ============================================================================

/// Opens a profile as the tall transparent bottom sheet used across the app.
/// One place for the sheet settings instead of two copies.
void _openProfileSheet(
    BuildContext context, {
      required String userId,
      required ProfileSeed seed,
    }) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    clipBehavior: Clip.none,
    barrierColor: Colors.black54,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (_) => ProfileDetailSheet(userId: userId, seed: seed),
  );
}

// ============================================================================
// Screen
// ============================================================================

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  _Tab _current = _Tab.radar;
  Timer? _appOpenAdTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushDeepLinks.pending.addListener(_onDeepLink);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onDeepLink();
      ref.read(appOpenAdControllerProvider.notifier).showAdIfEligible();
    });

    _appOpenAdTimer = Timer.periodic(kMinGapBetweenAppOpenAds, (_) {
      if (!mounted) return;
      ref.read(appOpenAdControllerProvider.notifier).showAdIfEligible();
    });
  }

  @override
  void dispose() {
    _appOpenAdTimer?.cancel();
    PushDeepLinks.pending.removeListener(_onDeepLink);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Switches tab and re-fetches the like quota, so a fresh purchase (or a
  /// used-up allowance) shows up as soon as the user comes back to a screen.
  ///
  /// The Radar tab re-fetches the nearby list itself when it opens (see
  /// [_RadarTabState.initState]), because the body is rebuilt on every switch.
  void _selectTab(_Tab tab) {
    if (tab == _current) return;
    setState(() => _current = tab);
    ref.read(likeQuotaProvider.notifier).refresh();
  }

  void _onDeepLink() {
    final link = PushDeepLinks.consume();
    if (link == null || !mounted) return;

    switch (link.destination) {
      case PushDestination.conversation:
        unawaited(_openConversation(link));
      case PushDestination.matches:
        setState(() => _current = _Tab.chats);
      case PushDestination.likes:
        setState(() => _current = _Tab.likes);
      case PushDestination.profile:
        setState(() => _current = _Tab.radar);
        final userId = link.userId;
        if (userId != null) {
          _openProfileSheet(
            context,
            userId: userId,
            seed: ProfileSeed(name: AppString.someoneFallback, colorIndex: 0),
          );
        }
      case PushDestination.url:
        break;
    }
  }

  Future<void> _openConversation(PushDeepLink link) async {
    final userId = link.userId;
    if (userId == null) return;

    ConversationSummary? summary;
    try {
      summary = await ref.read(chatRepositoryProvider).conversationWith(userId);
    } catch (_) {
      summary = null;
    }
    if (!mounted) return;

    if (summary == null) {
      setState(() => _current = _Tab.chats);
      return;
    }

    final found = summary;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: found.id,
          userId: found.otherUser.id,
          userName: found.otherUser.displayName ?? AppString.someoneFallback,
          userAge: found.otherUser.age,
          photoUrl: found.otherUser.primaryPhotoUrl,
          otherUser: found.otherUser,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
    ref.invalidate(likedYouProvider);
    ref.invalidate(mutualLikesProvider);
    ref.read(unreadCountProvider.notifier).refresh();
    ref.read(meProvider.notifier).refresh();
    ref.read(likeQuotaProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatRealtimeProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
        AppColors.isDark ? Brightness.light : Brightness.dark, // Android
        statusBarBrightness:
        AppColors.isDark ? Brightness.dark : Brightness.light, // iOS
      ),
      child: MatchCelebrationHost(
        child: Scaffold(
          // Must stay true so the floating bottom nav works.
          extendBody: true,
          backgroundColor: AppColors.background,
          body: SafeArea(bottom: false, child: _body()),
          // The banner sits directly above the floating bottom nav.
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BannerAdWidget(visible: _showsBannerAd(_current)),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 6, 15, 20),
                child: _BottomNav(
                  current: _current,
                  unread: ref.watch(unreadCountProvider).valueOrNull ?? 0,
                  onSelect: _selectTab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_current) {
    _Tab.radar => const _RadarTab(),
    _Tab.likes => const FavoritesScreen(),
    _Tab.explore => ExploreScreen(
      onBrowsePeople: () => _selectTab(_Tab.radar),
    ),
    _Tab.chats => const ChatsScreen(),
    _Tab.you => const YouScreen(),
  };

  bool _showsBannerAd(_Tab tab) =>
      tab == _Tab.likes || tab == _Tab.chats || tab == _Tab.you;
}

// ============================================================================
// Bottom navigation
// ============================================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.unread,
    required this.onSelect,
  });

  final _Tab current;
  final int unread;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.isDark
              ? AppColors.greyColor
              : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _Tab.values.map((tab) {
            final isActive = tab == current;
            final badge = tab == _Tab.chats ? unread : 0;

            return Semantics(
              button: true,
              selected: isActive,
              label: badge > 0 ? '${tab.label}, $badge unread' : tab.label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onSelect(tab),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          tab.icon,
                          size: 24,
                          color: isActive ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: _Badge(count: badge),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : 0),
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: AppTextStyles.caption.copyWith(
            fontSize: 9,
            height: 1,
            color: AppColors.onAccent,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Radar tab
// ============================================================================

class _RadarTab extends ConsumerStatefulWidget {
  const _RadarTab();

  @override
  ConsumerState<_RadarTab> createState() => _RadarTabState();
}

class _RadarTabState extends ConsumerState<_RadarTab> {
  @override
  void initState() {
    super.initState();

    // The dashboard rebuilds this tab every time the user switches to it, so
    // initState runs on each visit.
    //
    // If the nearby provider already exists, this is a return visit and the
    // list is re-fetched. If it does not exist yet, this is the first visit:
    // build() below will create it and load page 1 itself, so refreshing here
    // as well would send the request twice.
    final isReturnVisit = ref.exists(nearbyProvider);

    // After the first frame: a provider must not be changed while the widget
    // tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(likeQuotaProvider.notifier).refresh();
      if (isReturnVisit) ref.read(nearbyProvider.notifier).refresh();
    });
  }

  /// Pull-to-refresh: reload the quota together with the nearby list.
  Future<void> _onRefresh() async {
    ref.read(likeQuotaProvider.notifier).refresh();
    await ref.read(nearbyProvider.notifier).refresh();
  }

  /// The server answered 400: no location is set. Tell the user why the grid
  /// is empty. AppSnackBar ignores a repeat of the same message while it is
  /// still on screen, so back-to-back refreshes do not stack up.
  void _warnLocationMissing() {
    AppSnackBar.showWarningSnackBar(
      title: AppString.dashboardSetLocation,
      message: AppString.dashboardLocationPromptBody,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fires when a load finishes (first load, tab revisit, pull-to-refresh,
    // filter change). Skips the loading step, so the warning appears when the
    // 400 result arrives and not before.
    ref.listen<AsyncValue<NearbyState>>(nearbyProvider, (previous, next) {
      if (next.isLoading) return;
      if (next.valueOrNull?.needsLocation ?? false) _warnLocationMissing();
    });

    final nearbyAsync = ref.watch(nearbyProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final presence = ref.watch(presenceProvider);
    final me = ref.watch(meProvider).valueOrNull;

    return Column(
      children: [
        // Outside the scroll view, so it stays pinned while the grid scrolls.
        RadarHeader(
          name: me?.displayName,
          city: nearbyAsync.valueOrNull?.city ?? me?.location?.city,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _QuickFilters(
                    filter: filter,
                    isPremium: me?.premium.isActive ?? false,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                  sliver: nearbyAsync.when(
                    // A revisit re-fetches in the background. Keep showing the
                    // previous grid instead of flashing a spinner.
                    skipLoadingOnReload: true,
                    loading: () => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(
                      child: EmptyWidget(
                        title: AppString.dashboardLoadError,
                        body: AppString.dashboardConnectionError,
                      ),
                    ),
                    data: (state) => _grid(context, state, presence),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).withGlobalBackHandler(context);
  }

  Widget _grid(
      BuildContext context,
      NearbyState state,
      Map<String, bool> presence,
      ) {
    if (state.needsLocation) {
      return SliverToBoxAdapter(
        child: EmptyWidget(
          title: AppString.dashboardSetLocation,
          body: AppString.dashboardLocationPromptBody,
        ),
      );
    }

    final items = state.items;

    if (items.isEmpty && state.paywall == null) {
      // SliverFillRemaining gives the Center a bounded height (whatever is
      // left under the quick filters), so the empty state can be centred.
      //
      // The Scaffold uses extendBody, so this area runs underneath the floating
      // bottom nav (and banner ad). Centring in the full area made the content
      // look low. Padding the bottom by the nav's height moves the centre up to
      // the middle of what the user can actually see.
      final bottomInset = MediaQuery.paddingOf(context).bottom;

      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Center(
            child: EmptyWidget(
              compact: true,
              title: AppString.dashboardFilteredEmpty,
              body: AppString.dashboardFilteredEmptyBody,
              actionLabel: AppString.dashboardOpenFilters,
              onAction: () => showDiscoveryFilterSheet(context),
            ),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final card = items[index];
            final online = presence[card.id] ?? card.isOnline;
            return ProfileGridCard(
              name: card.displayName ?? AppString.someoneFallback,
              age: card.age,
              distanceBand: card.distanceBand,
              distanceMeters: card.distanceMeters,
              lastActiveAt: card.lastActiveAt,
              photoUrl: card.primaryPhotoUrl,
              isOnline: online,
              colorIndex: index,
              onTap: () {
                ref.read(recordProfileViewProvider)(card.id);
                _openProfileSheet(
                  context,
                  userId: card.id,
                  seed: ProfileSeed(
                    name: card.displayName ?? AppString.someoneFallback,
                    age: card.age,
                    photoUrl: card.primaryPhotoUrl,
                    distanceBand: card.distanceBand,
                    isOnline: online,
                    colorIndex: index,
                  ),
                );
              },
            );
          },
        ),
        if (state.hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: RadiusButton(
                label: state.loadingMore
                    ? AppString.loading
                    : AppString.dashboardShowMorePeople,
                kind: RadiusButtonKind.ghost,
                isLoading: state.loadingMore,
                onPressed: () => _showDiscoveryLimitDialog(context),
              ),
            ),
          ),
        if (state.paywall != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _UnlockCard(message: state.paywall?.message),
            ),
          ),
        SliverToBoxAdapter(child: spacerH(100)),
      ],
    );
  }

  Future<void> _showDiscoveryLimitDialog(BuildContext context) async {
    await AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.discoveryLimitTitle,
      descriptionText: AppString.discoveryLimitDescription,
      unlockType: RewardedUnlockType.getMoreProfiles,
      onAdEarned: () {
        ref.read(nearbyProvider.notifier).loadMore();
      },
    );
  }
}

/// Compact top bar. Lives outside the scroll view in [_RadarTab], so it stays
/// pinned while the grid scrolls.
class RadarHeader extends ConsumerWidget {
  const RadarHeader({super.key, this.name, this.city});

  final String? name;
  final String? city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = (city ?? '').trim();
    final fullName = (name ?? '').trim();
    final hasName = fullName.isNotEmpty;

    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final quota = ref.watch(likeQuotaProvider).valueOrNull ?? LikeQuota.empty;

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                AppVectors.appIconWhite,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppString.hiUser(hasName ? fullName : AppConstants.appName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                if (place.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            height: 1.2,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LikesMeter(
                quota: quota,
                onTap: () => showLikesTodaySheet(context),
              ),
              const _VisitorsButton(),
              _NotificationButton(unreadCount: unreadCount),
              const _FilterButton(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who visited my profile. An icon here rather than a tab — the same screen
/// also opens from the Visits number on the Me tab.
class _VisitorsButton extends StatelessWidget {
  const _VisitorsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      tooltip: AppString.visitorsOpen,
      onPressed: () => context.push(AppRoutes.visitors),
      icon: const Icon(Icons.visibility_outlined, size: 26),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          onPressed: () {
            AppLogger.d('Navigating to notifications...');
            context.push(AppRoutes.notifications);
          },
          icon: const Icon(Icons.notifications_none_rounded, size: 28),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppString.dashboardFiltersLabel,
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDiscoveryFilterSheet(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder, width: 1.5),
            ),
            child: Icon(Icons.tune, size: 18, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }
}

class _QuickFilters extends ConsumerWidget {
  const _QuickFilters({required this.filter, required this.isPremium});

  final DiscoveryFilter filter;
  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setFilter(DiscoveryFilter next) =>
        ref.read(discoveryFilterProvider.notifier).state = next;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // "All" is active only when no other filter is on; tapping it
          // resets the intent and both presence toggles.
          RadiusChip(
            label: AppString.all,
            dense: true,
            selected: filter.intent == null &&
                !filter.onlineOnly &&
                !filter.recentlyActive,
            onTap: () => setFilter(
              filter.copyWith(
                clearIntent: true,
                onlineOnly: false,
                recentlyActive: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _presenceChip(
            context,
            label: AppString.dashboardFilterOnlineNow,
            selected: filter.onlineOnly,
            onToggle: () =>
                setFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)),
          ),
          const SizedBox(width: 8),
          _presenceChip(
            context,
            label: AppString.dashboardFilterActiveToday,
            selected: filter.recentlyActive,
            onToggle: () => setFilter(
              filter.copyWith(recentlyActive: !filter.recentlyActive),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: AppColors.inputBorder,
          ),
          for (final entry in _filters) ...[
            RadiusChip(
              label: entry.key,
              dense: true,
              selected: entry.value == filter.intent,
              onTap: () => setFilter(
                filter.copyWith(
                  intent: entry.value,
                  clearIntent: entry.value == null,
                ),
              ),
            ),
            if (entry != _filters.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _presenceChip(
      BuildContext context, {
        required String label,
        required bool selected,
        required VoidCallback onToggle,
      }) {
    final locked = !isPremium;
    return RadiusChip(
      label: label,
      dense: true,
      locked: locked,
      selected: selected && isPremium,
      onTap: locked
          ? () => showPremiumFilterPrompt(context, filterName: label)
          : onToggle,
    );
  }
}

class _UnlockCard extends ConsumerStatefulWidget {
  const _UnlockCard({this.message});

  final String? message;

  @override
  ConsumerState<_UnlockCard> createState() => _UnlockCardState();
}

class _UnlockCardState extends ConsumerState<_UnlockCard> {
  bool _watching = false;

  Future<void> _watchAd() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final credits = await ref
          .read(adActionsProvider)
          .watchToUnlock(placement: 'nearby_unlock');
      if (!mounted) return;
      showRadiusToast(
        context,
        credits > 0
            ? AppString.dashboardUnlockedCredits(credits)
            : AppString.dashboardAlreadyCounted,
        tone: credits > 0 ? ToastTone.success : ToastTone.neutral,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RadiusCard(
      child: Column(
        children: [
          Text(
            AppString.dashboardSeenEveryone,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            widget.message ?? AppString.dashboardPremiumRadarBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          RadiusButton(
            label: AppString.dashboardSeePremium,
            kind: RadiusButtonKind.premium,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
          ),
          const SizedBox(height: 10),
          RadiusButton(
            label: _watching ? AppString.loading : AppString.watchAnAd,
            kind: RadiusButtonKind.ghost,
            isLoading: _watching,
            onPressed: _watchAd,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Static data
// ============================================================================

List<MapEntry<String, String?>> get _filters => [
  MapEntry(AppString.filterIntentRightNow, 'right_now'),
  MapEntry(AppString.filterIntentCasual, 'casual'),
  MapEntry(AppString.filterIntentDating, 'dating'),
  MapEntry(AppString.filterIntentSerious, 'serious'),
  MapEntry(AppString.filterIntentFriends, 'friends'),
  MapEntry(AppString.filterIntentJustChatting, 'just_chatting'),
  MapEntry(AppString.filterIntentOpenToAnything, 'open_to_anything'),
];

enum _Tab {
  radar(Icons.radar, 'Radar'),
  likes(Icons.favorite_border, 'Likes'),
  explore(Icons.explore_outlined, 'Explore'),
  chats(Icons.forum_outlined, 'Chats'),
  you(Icons.person_outline, 'You');

  const _Tab(this.icon, this.label);

  final IconData icon;
  final String label;

  String get localizedLabel => switch (this) {
    _Tab.radar => AppString.dashboardTabRadar,
    _Tab.likes => AppString.dashboardTabLikes,
    _Tab.explore => AppString.dashboardTabExplore,
    _Tab.chats => AppString.dashboardTabChats,
    _Tab.you => AppString.dashboardTabYou,
  };
}