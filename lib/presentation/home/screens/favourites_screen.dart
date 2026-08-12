import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/match_model.dart';
import '../../../providers/match_provider.dart';
import '../../common/widgets/widgets.dart';
import 'profile_detail_sheet.dart';
import './premium_screen.dart';

/// "Liked you" — the people who already made the first move.
///
/// The list is gated: the server returns `locked: true` with a count and no
/// identities, so the blurred grid here is showing nothing it was given. That
/// is deliberate — a paywall the client enforces is a paywall a proxy defeats.
///
/// Still named FavoritesScreen because the tab it backs is called Likes; the
/// second section ("people you liked", from the unused `favoritesProvider`)
/// arrives with the gating rework.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedYouProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.white,
      onRefresh: () async => ref.invalidate(likedYouProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(size: 24),
                  const SizedBox(height: 14),
                  Text('Liked you', style: AppTextStyles.display),
                  const SizedBox(height: 6),
                  Text(
                    'They already made the first move.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => const _Message(
                title: "Couldn't load your likes",
                body: 'Pull down to try again.',
              ),
              data: (page) => _body(context, page),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LikedYouPage page) {
    if (page.locked) return _LockedGrid(total: page.total);

    if (page.items.isEmpty) {
      return const _Message(
        title: 'No likes yet',
        body: 'Keep an eye on your radar — the people you like can see you '
            'too.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: page.items.length,
        itemBuilder: (context, index) {
          final card = page.items[index];
          return ProfileGridCard(
            name: card.displayName ?? 'Someone',
            age: card.age,
            photoUrl: card.primaryPhotoUrl,
            isOnline: card.isOnline,
            colorIndex: index,
            onTap: () => showRadiusSheet<void>(
              context: context,
              builder: (_) => ProfileDetailSheet(
                user: {
                  'id': card.id,
                  'name': card.displayName ?? 'Someone',
                  'age': card.age,
                  'distance': '',
                  'online': card.isOnline,
                  'color': kAvatarGradients[index % kAvatarGradients.length][0],
                  'photoUrl': card.primaryPhotoUrl,
                  'vibes': const <String>[],
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The gated state: placeholder tiles and a way to open them.
class _LockedGrid extends StatelessWidget {
  const _LockedGrid({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    // The server sends a count and nothing else, so the tile count is the only
    // honest thing to show. Three keeps the grid looking intentional when the
    // count is small.
    final tiles = total.clamp(0, 6) == 0 ? 3 : total.clamp(0, 6);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: tiles,
            itemBuilder: (_, index) => _LockedTile(index: index),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: RadiusCard(
            child: Column(
              children: [
                Text(
                  total > 0
                      ? '$total ${total == 1 ? 'person' : 'people'} liked you'
                      : 'See who liked you',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Premium reveals every one of them, and lets you reply.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                RadiusButton(
                  label: 'Reveal everyone with Premium',
                  kind: RadiusButtonKind.gold,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                RadiusButton(
                  label: 'Watch an ad',
                  kind: RadiusButtonKind.ghost,
                  onPressed: () => showRadiusToast(
                    context,
                    'Rewarded ads arrive in the next update.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A person the viewer has not unlocked.
///
/// `GET /likes/liked-you` returns `locked: true` with a count and **no items**,
/// so there is no photo here to blur — this renders the frosted placeholder
/// instead. Once the server starts sending downscaled thumbnails for locked
/// entries, pass them to [ProfileGridCard] with `blurred: true` and this widget
/// goes away.
class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hidden profile, unlock to see who this is',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: avatarGradient(index + 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          const RadarMark(size: 96, color: AppColors.iconMuted),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
