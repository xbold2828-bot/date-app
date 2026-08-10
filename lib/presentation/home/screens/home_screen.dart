import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/discovery_user_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../widgets/discovery_filter_sheet.dart';
import '../widgets/premium_filter_prompt.dart';
import './profile_detail_sheet.dart';
import './request_screen.dart';
import './favourites_screen.dart';
import './you_screen.dart';
import './premium_screen.dart';

/// Filter chips → backend `Intent` value (null = All). The full enum, so the
/// row matches what people actually chose during onboarding — with only four of
/// seven shown, anyone here for "Serious" or "Friends" was unreachable.
const List<MapEntry<String, String?>> _filters = [
  MapEntry('All', null),
  MapEntry('Right now', 'right_now'),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Serious', 'serious'),
  MapEntry('Friends', 'friends'),
  MapEntry('Just chatting', 'just_chatting'),
  MapEntry('Open to anything', 'open_to_anything'),
];

const List<Color> _cardColors = [
  Color(0xFFB5A89A),
  Color(0xFF8B6F6F),
  Color(0xFF4A4A5A),
  Color(0xFFB8C8D0),
  Color(0xFFC8C0D0),
  Color(0xFFD4C0B0),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    // Activate the live chat badge/inbox refresh while the app is open.
    ref.watch(chatRealtimeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCurrentTab()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 1:
        return const RequestsScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return const YouScreen();
      case 0:
      default:
        return const _NearbyTab();
    }
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.explore, 'label': 'Nearby'},
      {'icon': Icons.mail_outline, 'label': 'Requests'},
      {'icon': Icons.favorite_border, 'label': 'Favorites'},
      {'icon': Icons.person_outline, 'label': 'You'},
    ];

    // Live unread total: seeded by REST, then bumped by the chat socket, so a
    // new message lights up Requests immediately from any tab.
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.inputBorder, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isActive = _currentTab == index;
          return GestureDetector(
            onTap: () => setState(() => _currentTab = index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      size: 24,
                      color: isActive ? AppColors.primary : AppColors.textGrey,
                    ),
                    // Requests only. Shown even on the active tab: the count is
                    // truthful until the thread itself is actually read.
                    if (index == 1 && unread > 0)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: unread > 9 ? 4 : 0,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  items[index]['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppColors.primary : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NearbyTab extends ConsumerWidget {
  const _NearbyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final presence = ref.watch(presenceProvider);
    final me = ref.watch(meProvider).valueOrNull;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(nearbyProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _header(
                context, nearbyAsync.valueOrNull?.city ?? me?.location?.city),
            const SizedBox(height: 20),
            _filterChips(
              context,
              ref,
              filter,
              me?.premium.isActive ?? false,
            ),
            const SizedBox(height: 28),
            nearbyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => _message(
                "Couldn't load people nearby.\n$err",
              ),
              data: (state) => _nearbyBody(context, ref, state, presence),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String? city) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Near you',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              city == null || city.isEmpty ? 'Around you' : city,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => showDiscoveryFilterSheet(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: const Icon(Icons.tune, size: 20, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }

  /// Quick filters: the two premium presence toggles first (they're what people
  /// reach for most), then the single-select intent chips.
  Widget _filterChips(
    BuildContext context,
    WidgetRef ref,
    DiscoveryFilter filter,
    bool isPremium,
  ) {
    void setFilter(DiscoveryFilter next) =>
        ref.read(discoveryFilterProvider.notifier).state = next;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toggleChip(
            context,
            label: 'Online',
            icon: Icons.circle,
            selected: filter.onlineOnly,
            isPremium: isPremium,
            onToggle: () =>
                setFilter(filter.copyWith(onlineOnly: !filter.onlineOnly)),
          ),
          _toggleChip(
            context,
            label: 'Recently active',
            icon: Icons.schedule,
            selected: filter.recentlyActive,
            isPremium: isPremium,
            onToggle: () => setFilter(
                filter.copyWith(recentlyActive: !filter.recentlyActive)),
          ),
          // A little air between the presence toggles and the intent chips —
          // they behave differently (multi-toggle vs single-select).
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.only(right: 8),
            color: AppColors.inputBorder,
          ),
          ..._filters.map((entry) {
            final isSelected = entry.value == filter.intent;
            return GestureDetector(
              // copyWith, not a fresh DiscoveryFilter: building a new one here
              // silently threw away the radius and premium toggles every time
              // an intent chip was tapped.
              onTap: () => setFilter(filter.copyWith(
                intent: entry.value,
                clearIntent: entry.value == null,
              )),
              child: _chipShell(
                selected: isSelected,
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppColors.white : AppColors.textDark,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// A premium presence toggle. Free members see it frozen with a padlock;
  /// tapping explains the gate instead of firing a request the API would 403.
  Widget _toggleChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required bool isPremium,
    required VoidCallback onToggle,
  }) {
    final locked = !isPremium;
    final on = selected && isPremium;

    return GestureDetector(
      onTap: locked
          ? () => showPremiumFilterPrompt(context, filterName: label)
          : onToggle,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: _chipShell(
          selected: on,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locked ? Icons.lock_outline : icon,
                size: locked ? 13 : (icon == Icons.circle ? 9 : 13),
                color: on
                    ? AppColors.white
                    : (locked ? AppColors.textGrey : Colors.green),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: on ? AppColors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipShell({required bool selected, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.textDark : AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected ? AppColors.textDark : AppColors.inputBorder,
        ),
      ),
      child: child,
    );
  }

  Widget _nearbyBody(
    BuildContext context,
    WidgetRef ref,
    NearbyState state,
    Map<String, bool> presence,
  ) {
    if (state.needsLocation) {
      return _message(
        'Set your location to discover people near you.',
        icon: Icons.location_off_outlined,
      );
    }

    final items = state.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty) ...[
          const Text(
            'In your circle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          // Three across, flowing downward. The page itself is the only
          // scroller — shrinkWrap + NeverScrollable keeps this grid from
          // fighting the outer SingleChildScrollView, so browsing is one
          // continuous vertical scroll instead of a sideways filmstrip.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              // Portrait cards, matching the old 130×180 proportions.
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) => _circleCard(
              context,
              items[index],
              presence[items[index].id] ?? items[index].isOnline,
              index,
            ),
          ),
          const SizedBox(height: 24),
          if (state.hasMore)
            Center(
              child: TextButton(
                onPressed: () => ref.read(nearbyProvider.notifier).loadMore(),
                child: Text(
                  state.loadingMore ? 'Loading…' : 'Load more',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ] else if (state.paywall == null)
          _message(
            'No one nearby right now. Try widening your radius.',
            icon: Icons.person_search_outlined,
          ),
        if (state.paywall != null) _paywall(context, ref, state),
      ],
    );
  }

  Widget _circleCard(
    BuildContext context,
    DiscoveryCard card,
    bool online,
    int index,
  ) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProfileDetailSheet(
          user: {
            'id': card.id,
            'name': card.displayName ?? 'Someone',
            'age': card.age,
            'distance': card.distanceBand,
            'online': online,
            'color': _cardColors[index % _cardColors.length],
            'bio': null,
            'vibes': card.personalityTags,
            'photoUrl': card.primaryPhotoUrl,
          },
        ),
      ),
      child: Container(
        // No fixed width — the grid cell sets it, so cards scale with the
        // screen instead of overflowing on narrow phones.
        decoration: BoxDecoration(
          color: _cardColors[index % _cardColors.length],
          borderRadius: BorderRadius.circular(16),
          image: card.primaryPhotoUrl != null
              ? DecorationImage(
                  image: NetworkImage(card.primaryPhotoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: online ? Colors.green : AppColors.textGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.age != null
                        ? '${card.displayName ?? 'Someone'}, ${card.age}'
                        : (card.displayName ?? 'Someone'),
                    // A third of the width is tight — clip long names rather
                    // than letting them wrap over the card edge.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 10, color: AppColors.white),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          card.distanceBand,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paywall(BuildContext context, WidgetRef ref, NearbyState state) {
    return Center(
      child: Column(
        children: [
          const Text(
            'Discovery Limit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.paywall?.message ?? 'Unlock more nearby',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rewarded ads arrive in the next update.')),
            ),
            child: const Text(
              'Watch an ad to unlock',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, {IconData icon = Icons.info_outline}) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
