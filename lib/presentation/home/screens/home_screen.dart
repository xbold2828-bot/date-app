import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../../explore/screens/explore_screen.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/match_celebration.dart';
import '../widgets/premium_filter_prompt.dart';
import './profile_detail_sheet.dart';
import './request_screen.dart';
import './favourites_screen.dart';
import './you_screen.dart';
import './premium_screen.dart';

/// Intent chips → backend `Intent` value. The full enum, so the row matches
/// what people actually chose during onboarding — with only four of seven
/// shown, anyone here for "Serious" or "Friends" was unreachable.
///
/// "All" is not in this list: it clears the intent rather than setting one, and
/// it leads the row ahead of the presence toggles. See [_QuickFilters].
const List<MapEntry<String, String?>> _filters = [
  MapEntry('Right now', 'right_now'),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Serious', 'serious'),
  MapEntry('Friends', 'friends'),
  MapEntry('Just chatting', 'just_chatting'),
  MapEntry('Open to anything', 'open_to_anything'),
];

/// The five destinations, in the order they appear in the bar.
///
/// Explore sits in the middle, between the two feeds and the two inboxes —
/// it is the browsing surface, and putting it beside Chats would have grouped
/// it with the things that are about people you have already met.
enum _Tab {
  radar(Icons.radar, 'Radar'),
  likes(Icons.favorite_border, 'Likes'),
  // `explore_outlined` over `map_outlined`: the compass rose is the closer
  // sibling of the radar mark the app is built around.
  explore(Icons.explore_outlined, 'Explore'),
  chats(Icons.forum_outlined, 'Chats'),
  you(Icons.person_outline, 'You');

  const _Tab(this.icon, this.label);

  final IconData icon;
  final String label;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  _Tab _current = _Tab.radar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-read what may have changed while the app was in the background.
  ///
  /// Deliberately NOT the radar: `GET /discovery/nearby` consumes a free daily
  /// view, so refreshing it on every resume would spend somebody's whole
  /// allowance just by switching apps. The grid stays a snapshot until it is
  /// pulled to refresh — and every profile opened from it is fetched live, so
  /// what people actually read is never stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
    ref.invalidate(likedYouProvider);
    ref.invalidate(mutualLikesProvider);
    ref.read(unreadCountProvider.notifier).refresh();
    ref.read(meProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Activate the live chat badge/inbox refresh while the app is open.
    ref.watch(chatRealtimeProvider);

    // Wraps the whole app surface: a match can arrive from the socket while
    // the person is on any tab, and the celebration should not belong to
    // whichever screen happens to be underneath it.
    return MatchCelebrationHost(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: _body()),
              _BottomNav(
                current: _current,
                // Live unread total: seeded by REST, then bumped by the chat
                // socket, so a new message lights up Chats from any tab.
                unread: ref.watch(unreadCountProvider).valueOrNull ?? 0,
                onSelect: (tab) => setState(() => _current = tab),
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
        // Explore only shows people who have replied to you, so its empty
        // state has to be able to send you somewhere you can meet them — and
        // the tab bar lives here, not there.
        _Tab.explore => ExploreScreen(
            onBrowsePeople: () => setState(() => _current = _Tab.radar),
          ),
        _Tab.chats => const RequestsScreen(),
        _Tab.you => const YouScreen(),
      };
}

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        10,
        8,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: _Tab.values.map((tab) {
          final isActive = tab == current;
          // Chats only. Shown even on the active tab: the count stays truthful
          // until the thread itself is actually read.
          final badge = tab == _Tab.chats ? unread : 0;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isActive,
              label: badge > 0
                  ? '${tab.label}, $badge unread'
                  : tab.label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onSelect(tab),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            tab.icon,
                            size: 22,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.iconMuted,
                          ),
                          if (badge > 0)
                            Positioned(
                              top: -3,
                              right: -6,
                              child: _Badge(count: badge),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        // Five tabs leave ~62dp each on a 320dp phone, and
                        // "Explore" is the longest label in the bar. Clip
                        // rather than let it wrap the row taller.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textGrey,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          fontVariations: [
                            FontVariation('wght', isActive ? 700 : 500),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
        border: Border.all(color: AppColors.panel, width: 2),
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
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: _EmptyState(
                  title: "Couldn't load your radar",
                  body: 'Check your connection and pull down to try again.',
                ),
              ),
              data: (state) => _grid(context, ref, state, presence),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    NearbyState state,
    Map<String, bool> presence,
  ) {
    if (state.needsLocation) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          title: 'Set your location',
          body: 'cozune needs to know roughly where you are before it can '
              'show you who is nearby.',
        ),
      );
    }

    final items = state.items;

    if (items.isEmpty && state.paywall == null) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          title: 'Quiet in your radius right now',
          body: 'Nobody nearby matches these filters. Clear a few and check '
              'back — who is around changes through the day.',
          action: RadiusButton(
            label: 'Open filters',
            kind: RadiusButtonKind.ghost,
            onPressed: () => showDiscoveryFilterSheet(context),
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
            // Portrait cards. The grid cell sets the width, so they scale
            // with the screen instead of overflowing on narrow phones.
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
              // The sheet fetches the full profile itself; the seed is only so
              // the name and photo already on screen stay on screen.
              onTap: () {
                // Counts as a visit on their profile. Not awaited, and it
                // cannot throw — opening the sheet must not wait on, or be
                // stopped by, a counter. The server ignores repeats within the
                // day, so a scroll back and forth is one visit.
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
                onPressed: () => ref.read(nearbyProvider.notifier).loadMore(),
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
}

/// Greeting, place, and the mark.
///
/// The mark used to fill its rings to the radius the account was set to. There
/// is no such setting any more — nobody picks a search radius — so it renders
/// as the plain brand mark and the line under the greeting is just the city.
class RadarHeader extends StatelessWidget {
  const RadarHeader({super.key, this.name, this.city});

  final String? name;
  final String? city;

  @override
  Widget build(BuildContext context) {
    final place = (city ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          const RadarMark(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // The wave rides along with the name — on "Your radar" there
                  // is nobody being greeted, so it would just be decoration.
                  name == null || name!.isEmpty
                      ? 'Your radar'
                      : 'Hey, $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(fontSize: 19),
                ),
                if (place.isNotEmpty)
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // No Premium pill. It sat between the greeting and Filters as a
          // permanent advertisement on the screen people open the app to use,
          // and it squeezed the name into an ellipsis to do it. Premium is
          // still reachable from the "You" tab and from every paywall that has
          // an actual reason to appear.
          //
          // Filters sits in the header rather than at the tail of the chip
          // row: there it was only reachable after scrolling past eight intent
          // chips, which buried the one control that fixes an empty radar.
          const _FilterButton(),
        ],
      ),
    );
  }
}

/// Opens the full filter sheet.
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

/// The horizontal chip row: "All" first, then the two premium presence
/// toggles, then the intent chips.
///
/// "All" leads because it is the way back to an unfiltered radar, and burying
/// the reset behind a scroll is how people end up stuck on an empty grid
/// wondering where everyone went.
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters({required this.filter, required this.isPremium});

  final DiscoveryFilter filter;
  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setFilter(DiscoveryFilter next) =>
        ref.read(discoveryFilterProvider.notifier).state = next;

    // Sizes to the chips rather than to a fixed height. A hard height here
    // squeezed the row below what the chips need and sliced the descenders off
    // "Just chatting" and "Open to anything" — and it would have broken again
    // the moment anyone raised their system text size.
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
          // A little air before the intent chips — they behave differently
          // from everything to the left (single-select vs toggle).
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: AppColors.inputBorder,
          ),
          // Intent chips only — "Filters" now lives in the header, where it is
          // reachable without scrolling.
          for (final entry in _filters) ...[
            RadiusChip(
              label: entry.key,
              dense: true,
              selected: entry.value == filter.intent,
              // copyWith, not a fresh DiscoveryFilter: building a new one here
              // silently threw away the radius and premium toggles every time
              // an intent chip was tapped.
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

  /// A premium presence toggle. Free members see it with a padlock; tapping
  /// explains the gate instead of firing a request the API would reject.
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

/// Shown when the server stops handing out profiles.
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

/// An empty screen is an invitation to act, so every one of these carries a
/// way forward rather than just an apology.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      child: Column(
        children: [
          RadarMark(
            size: 104,
            animate: true,
            color: AppColors.iconMuted,
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
          if (action != null) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: action!,
            ),
          ],
        ],
      ),
    );
  }
}
