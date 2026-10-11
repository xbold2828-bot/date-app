import 'package:dating_app/core/extensions/padding_extension.dart';
import 'package:dating_app/core/utils/app_loader.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_string.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/widgets/premium_tab_bar.dart';
import '../models/profile_seed.dart';
import '../providers/match_provider/match_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../common/widgets/widgets.dart';
import 'chat_detail_screen.dart';
import 'profile_detail_sheet.dart';
import './premium_screen.dart';

/// Opens the profile sheet with a transparent wrapper, so the bottom sheet's
/// own Material never draws a white edge around it.
Future<void> _showProfileSheet(
    BuildContext context, {
      required String userId,
      required ProfileSeed seed,
    }) {
  return showModalBottomSheet<void>(
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

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(size: 24),
          ),
        ),
        spacerH(10),
        PremiumTabBar(
          controller: _tabs,
          tabs: const [
            PremiumTabItem(label: 'Likes', icon: Icons.favorite_rounded),
            PremiumTabItem(label: 'Mutual', icon: Icons.people_alt_rounded),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_LikedYouTab(), _MutualTab()],
          ),
        ),
      ],
    ).withGlobalBackHandler(context);
  }
}

/// Incoming likes you have not answered. Freemium.
class _LikedYouTab extends ConsumerWidget {
  const _LikedYouTab();

  /// Everyone who liked you: the ones shown in full plus the ones still hidden.
  int _totalLikes(LikedYouPage page) {
    final visible = page.items.where((c) => !c.locked).length;
    return visible + page.lockedCount;
  }

  String _subtitle(LikedYouPage? page) {
    if (page == null) return 'They already made the first move.';
    final total = _totalLikes(page);
    if (total == 0) return 'They already made the first move.';
    return total == 1 ? '1 person liked you' : '$total people liked you';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedYouProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(likedYouProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: LoaderWidget()),
                ),
                error: (err, _) => const EmptyWidget(
                  title: "Couldn't load your likes",
                  body: 'Pull down to try again.',
                ),
                data: (page) => _body(context, ref, page),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, LikedYouPage page) {
    if (page.isEmpty) {
      return const EmptyWidget(
        isLikePage: true,
        title: 'No likes yet',
        body: 'Keep an eye on your radar — the people you like can see you '
            'too.',
      ).paddingOnly(top: 20.h);
    }

    return _buildContent(context, ref, page);
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, LikedYouPage page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liked you', style: AppTextStyles.display),
              const SizedBox(height: 6),
              Text(_subtitle(page), style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Grid
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w).copyWith(top: 10.h),
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
            itemBuilder: (context, index) => _tile(
              context,
              ref,
              page.items[index],
              index,
            ),
          ),
        ),
      ],
    );
  }

  /// Premium, or watch an ad. After the ad, [AdActions.unlockLikedYou] mints
  /// the credit and — when [card] has a usable id — spends it to reveal this
  /// specific card in the same round trip.
  Future<void> _showUnlockDialog(
      BuildContext context,
      WidgetRef ref,
      LikeCard card,
      ) async {
    if (card.id.isEmpty) {
      showRadiusToast(
        context,
        "User Id is Empty",
        tone: ToastTone.error,
      );
      return;
    }

    return AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.seeWhoLikedYouTitle,
      descriptionText: AppString.seeWhoLikedYouDescription,
      unlockType: RewardedUnlockType.seeWhoLikedYou,
      onAdEarned: () async {
        try {
          final (message, success) = await ref
              .read(adActionsProvider)
              .unlockLikedYou(card.id, placement: 'likes_unlock');

          if (!context.mounted) return;
          showRadiusToast(
            context,
            message,
            tone: success ? ToastTone.success : ToastTone.error,
          );
        } on AppException catch (e) {
          if (context.mounted) {
            showRadiusToast(context, e.message, tone: ToastTone.error);
          }
        }
      },
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, LikeCard card, int index) {
    if (card.locked) {
      // Tapping offers the unlock (Premium, or watch an ad).
      return ProfileGridCard(
        name: '',
        colorIndex: index,
        isOnline: card.isOnline,
        blurred: true,
        onTap: () => _showUnlockDialog(context, ref, card),
      );
    }

    final name = card.displayName ?? 'Someone';
    return ProfileGridCard(
      name: name,
      age: card.age,
      photoUrl: card.primaryPhotoUrl,
      distanceMeters: card.distanceMeters,
      lastActiveAt: card.lastActiveAt,
      isOnline: card.isOnline,
      isVerified: card.isVerified,
      colorIndex: index,
      onTap: () => _showProfileSheet(
        context,
        userId: card.id,
        seed: ProfileSeed(
          name: name,
          age: card.age,
          photoUrl: card.primaryPhotoUrl,
          isOnline: card.isOnline,
          colorIndex: index,
        ),
      ),
    );
  }
}

/// Matches. Free, complete, and one tap from a conversation.
class _MutualTab extends ConsumerWidget {
  const _MutualTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mutualLikesProvider);
    final presence = ref.watch(presenceProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(mutualLikesProvider),
      child: async.when(
        loading: () => const Center(child: LoaderWidget()),
        error: (err, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyWidget(
              title: "Couldn't load your matches",
              body: 'Pull down to try again.',
            ),
          ],
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyWidget(
                  title: 'No matches yet',
                  body: 'When you like someone who already liked you, they '
                      'show up here — free to message, always.',
                ),
              ],
            );
          }

          // WhatsApp-style list: full-width rows, no cards, and a hairline
          // divider that starts after the avatar.
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.6,
              indent: 86,
              endIndent: 16,
              color: AppColors.inputBorder,
            ),
            itemBuilder: (_, index) {
              final match = page.items[index];
              return _MutualRow(
                match: match,
                colorIndex: index,
                online: presence[match.user.id] ?? match.user.isOnline,
              );
            },
          );
        },
      ),
    );
  }
}

/// A match, laid out like a WhatsApp chat row: round avatar on the left,
/// bold name over a grey one-line subtitle, action on the right.
class _MutualRow extends ConsumerWidget {
  const _MutualRow({
    required this.match,
    required this.colorIndex,
    required this.online,
  });

  final MutualCard match;
  final int colorIndex;
  final bool online;

  String get _name => match.user.displayName ?? 'Someone';

  void _openProfile(BuildContext context) {
    _showProfileSheet(
      context,
      userId: match.user.id,
      seed: ProfileSeed(
        name: _name,
        age: match.user.age,
        photoUrl: match.user.primaryPhotoUrl,
        isOnline: online,
        colorIndex: colorIndex,
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    await AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.mutualChatPaywallTitle,
      descriptionText: AppString.mutualChatPaywallDescription,
      unlockType: RewardedUnlockType.unlockChat,
      onAdEarned: () {
        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversationId: match.conversationId,
              userId: match.user.id,
              userName: _name,
              userAge: match.user.age,
              photoUrl: match.user.primaryPhotoUrl,
              colorIndex: colorIndex,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Match with $_name${online ? ', online now' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProfile(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _MatchAvatar(
                  name: _name,
                  photoUrl: match.user.primaryPhotoUrl,
                  colorIndex: colorIndex,
                  online: online,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        match.user.age != null
                            ? '$_name, ${match.user.age}'
                            : _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        match.conversationId == null
                            ? 'You both liked each other'
                            : 'You have a conversation going',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13.5,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Message $_name',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _openChat(context, ref),
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({
    required this.name,
    required this.colorIndex,
    required this.online,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final int colorIndex;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoUrl == null ? avatarGradient(colorIndex) : null,
              image: photoUrl != null
                  ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: photoUrl == null
                ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.avatarInitial(22),
              ),
            )
                : null,
          ),
          if (online)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.onImage, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The counter and the two ways past it.
class _UnlockCard extends ConsumerStatefulWidget {
  const _UnlockCard({required this.remaining});

  /// People the viewer still cannot see. This is the whole pitch, so it leads.
  final int remaining;

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
          .watchToUnlock(placement: 'likes_unlock');

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
    final n = widget.remaining;

    return RadiusCard(
      child: Column(
        children: [
          Text(
            n == 1 ? '1 more person liked you' : '$n more people liked you',
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