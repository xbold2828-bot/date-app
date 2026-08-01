import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/discovery_user_model.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import './profile_detail_sheet.dart';
import './request_screen.dart';
import './favourites_screen.dart';
import './you_screen.dart';
import './premium_screen.dart';

/// Filter tabs → backend `intent` value (null = All).
const List<MapEntry<String, String?>> _filters = [
  MapEntry('All', null),
  MapEntry('Casual', 'casual'),
  MapEntry('Dating', 'dating'),
  MapEntry('Right now', 'right_now'),
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
                Icon(
                  items[index]['icon'] as IconData,
                  size: 24,
                  color: isActive ? AppColors.primary : AppColors.textGrey,
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
            _header(nearbyAsync.valueOrNull?.city ?? me?.location?.city),
            const SizedBox(height: 20),
            _filterChips(ref, filter.intent),
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

  Widget _header(String? city) {
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: const Icon(Icons.tune, size: 20, color: AppColors.textDark),
        ),
      ],
    );
  }

  Widget _filterChips(WidgetRef ref, String? activeIntent) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((entry) {
          final isSelected = entry.value == activeIntent;
          return GestureDetector(
            onTap: () => ref.read(discoveryFilterProvider.notifier).state =
                DiscoveryFilter(intent: entry.value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.textDark : AppColors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppColors.textDark : AppColors.inputBorder,
                ),
              ),
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
        }).toList(),
      ),
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
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _circleCard(
                context,
                items[index],
                presence[items[index].id] ?? items[index].isOnline,
                index,
              ),
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
        width: 130,
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
              top: 10,
              right: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? Colors.green : AppColors.textGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.age != null
                        ? '${card.displayName ?? 'Someone'}, ${card.age}'
                        : (card.displayName ?? 'Someone'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 11, color: AppColors.white),
                      const SizedBox(width: 2),
                      Text(
                        card.distanceBand,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.white,
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
