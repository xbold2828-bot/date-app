import 'dart:async';
import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/extensions/global_back_extension.dart';
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
// Screen
// ============================================================================

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  _Tab _current = _Tab.radar;
  Timer? _appOpenAdTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushDeepLinks.pending.addListener(_onDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDeepLink());

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          showRadiusSheet<void>(
            context: context,
            builder: (_) => ProfileDetailSheet(
              userId: userId,
              seed: const ProfileSeed(name: 'Someone', colorIndex: 0),
            ),
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: summary!.id,
          userId: summary.otherUser.id,
          userName: summary.otherUser.displayName ?? 'Someone',
          userAge: summary.otherUser.age,
          photoUrl: summary.otherUser.primaryPhotoUrl,
          otherUser: summary.otherUser,
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
        statusBarIconBrightness: AppColors.isDark ? Brightness.light : Brightness.dark, // Android
        statusBarBrightness: AppColors.isDark ? Brightness.dark : Brightness.light, // iOS
      ),
      child: MatchCelebrationHost(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(child: _body()),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BannerAdWidget(visible: _showsBannerAd(_current)),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _BottomNav(
              current: _current,
              unread: ref.watch(unreadCountProvider).valueOrNull ?? 0,
              onSelect: (tab) => setState(() => _current = tab),
            ),
          ),
        )
      ),
    );
  }

  Widget _body() => switch (_current) {
    _Tab.radar => const _RadarTab(),
    _Tab.likes => const FavoritesScreen(),
    _Tab.explore => ExploreScreen(
      onBrowsePeople: () => setState(() => _current = _Tab.radar),
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
          color:  AppColors.isDark ? AppColors.greyColor.withValues(alpha: 0.5) : AppColors.whiteColor,
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
                          color:
                          isActive ? AppColors.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          tab.icon,
                          size: 22,
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

class _RadarTab extends ConsumerWidget {
  const _RadarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final presence = ref.watch(presenceProvider);
    final me = ref.watch(meProvider).valueOrNull;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () => ref.read(nearbyProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: RadarHeader(
              name: me?.displayName,
              city: nearbyAsync.valueOrNull?.city ?? me?.location?.city,
            ),
          ),
          SliverToBoxAdapter(
            child: _QuickFilters(
              filter: filter,
              isPremium: me?.premium.isActive ?? false,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            sliver: nearbyAsync.when(
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
              error: (err, _) => const SliverToBoxAdapter(
                child: EmptyWidget(
                  title: "Couldn't load your radar",
                  body: 'Check your connection and pull down to try again.',
                ),
              ),
              data: (state) => _grid(context, ref, state, presence),
            ),
          ),
        ],
      ),
    ).withGlobalBackHandler(context);
  }

  Widget _grid(
      BuildContext context,
      WidgetRef ref,
      NearbyState state,
      Map<String, bool> presence,
      ) {
    if (state.needsLocation) {
      return const SliverToBoxAdapter(
        child: EmptyWidget(
          title: 'Set your location',
          body: 'cozune needs to know roughly where you are before it can '
              'show you who is nearby.',
        ),
      );
    }

    final items = state.items;

    if (items.isEmpty && state.paywall == null) {
      return SliverToBoxAdapter(
        child: EmptyWidget(
          title: 'Quiet in your radius right now',
          body: 'Nobody nearby matches these filters. Clear a few and check '
              'back — who is around changes through the day.',
          actionLabel: 'Open filters',
          onAction: () => showDiscoveryFilterSheet(context),
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
              name: card.displayName ?? 'Someone',
              age: card.age,
              distanceBand: card.distanceBand,
              distanceMeters: card.distanceMeters,
              lastActiveAt: card.lastActiveAt,
              photoUrl: card.primaryPhotoUrl,
              isOnline: online,
              colorIndex: index,
              onTap: () {
                ref.read(recordProfileViewProvider)(card.id);

                showRadiusSheet<void>(
                  context: context,
                  builder: (_) => ProfileDetailSheet(
                    userId: card.id,
                    seed: ProfileSeed(
                      name: card.displayName ?? 'Someone',
                      age: card.age,
                      photoUrl: card.primaryPhotoUrl,
                      distanceBand: card.distanceBand,
                      isOnline: online,
                      colorIndex: index,
                    ),
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
                label: state.loadingMore ? 'Loading' : 'Show more people',
                kind: RadiusButtonKind.ghost,
                isLoading: state.loadingMore,
                onPressed: () {
                  _showDiscoveryLimitDialog(
                    context,ref
                  );
                  // ref.read(nearbyProvider.notifier).loadMore(); // This is the rewared

                  },
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
      ],
    );
  }


  void _showDiscoveryLimitDialog(BuildContext context, WidgetRef ref) async {
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo badge
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha:0.25),
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
            const SizedBox(width: 14),

            // Greeting + location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasName ? 'Hey 👋' : 'Welcome to',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasName ? fullName : AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                _NotificationButton(unreadCount: unreadCount),
                const _FilterButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracted Notification button for a cleaner build method.
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
            AppLogger.d("Navigating to notifications...");
            context.push(AppRoutes.notifications);
          },
          // Outlined icon looks more elegant/premium than a heavy filled icon
          icon: const Icon(
            Icons.notifications_none_rounded,
            size: 28,
          ),
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
                  // Creates a premium "cutout" effect against the background
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
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
      label: 'Filters',
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
            child: Icon(
              Icons.tune,
              size: 18,
              color: AppColors.textDark,
            ),
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
          RadiusChip(
            label: 'All',
            dense: true,
            selected: filter.intent == null,
            onTap: () => setFilter(filter.copyWith(clearIntent: true)),
          ),
          const SizedBox(width: 8),
          _presenceChip(
            context,
            label: 'Online now',
            selected: filter.onlineOnly,
            onToggle: () =>
                setFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)),
          ),
          const SizedBox(width: 8),
          _presenceChip(
            context,
            label: 'Active today',
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
              onTap: () => setFilter(filter.copyWith(
                intent: entry.value,
                clearIntent: entry.value == null,
              )),
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
            ? 'Unlocked — $credits credits added'
            : 'That one was already counted',
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
            'You have seen everyone for now',
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            widget.message ??
                'Premium opens the rest of your radius, with no daily limit.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          RadiusButton(
            label: 'See everyone with Premium',
            kind: RadiusButtonKind.premium,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
          ),
          const SizedBox(height: 10),
          RadiusButton(
            label: _watching ? 'Loading' : 'Watch an ad',
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

const List<MapEntry<String, String?>> _filters = [
  MapEntry('Right now', 'right_now'),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Serious', 'serious'),
  MapEntry('Friends', 'friends'),
  MapEntry('Just chatting', 'just_chatting'),
  MapEntry('Open to anything', 'open_to_anything'),
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
}