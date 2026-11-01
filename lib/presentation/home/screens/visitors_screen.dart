import 'package:dating_app/core/utils/app_loader.dart';
import 'package:dating_app/shared/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_string.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/visitor_model.dart';
import '../../../providers/visitors_provider.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../../shared/widgets/dialogs/all_dialogs/radius_dialog.dart';
import '../../common/widgets/widgets.dart';
import '../models/profile_seed.dart';
import 'profile_detail_sheet.dart';

/// Who opened my profile. Reached from the eye on the radar header and from
/// the Visits number on the Me tab — not a tab of its own.
///
/// Sold like Liked-you: a free member reveals a few visitors of their choosing
/// for nothing, then one per rewarded ad; Premium sees everyone. A blurred
/// tile is empty server-side, so the blur is decoration, not the lock.
class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  /// Visits being revealed right now, so a second tap does not pay twice.
  final Set<String> _revealing = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppString.visitorsTitle,
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(visitorsProvider),
          child: async.when(
            loading: () => const Center(child: LoaderWidget()),
            error: (_, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyWidget(
                  title: AppString.visitorsLoadFailed,
                  body: 'Pull down to try again.',
                ),
              ],
            ),
            data: (page) => page.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyWidget(
                        title: AppString.visitorsEmptyTitle,
                        body: AppString.visitorsEmptyBody,
                      ),
                    ],
                  )
                : _grid(page),
          ),
        ),
      ),
    );
  }

  Widget _grid(VisitorsPage page) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.total == 1
                      ? '1 person visited you'
                      : '${page.total} people visited you',
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(_subtitle(page), style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: page.items.length,
            itemBuilder: (context, index) =>
                _tile(page, page.items[index], index),
          ),
        ),
      ],
    );
  }

  /// What a reveal costs right now, so the next tap holds no surprise.
  String _subtitle(VisitorsPage page) {
    final unlocks = page.unlocks;
    if (unlocks == null || !page.locked) return AppString.visitorsWindow;
    final free = unlocks.freeRemaining;
    if (free > 0) {
      return free == 1
          ? 'Tap a photo to reveal them. 1 free reveal left.'
          : 'Tap a photo to reveal them. $free free reveals left.';
    }
    return AppString.visitorsAdEach;
  }

  Widget _tile(VisitorsPage page, VisitorCard visitor, int index) {
    final user = visitor.user;
    if (visitor.locked) {
      return ProfileGridCard(
        name: '',
        colorIndex: index,
        isOnline: user.isOnline,
        blurred: true,
        onTap: () => _reveal(page, visitor),
      );
    }

    final name = user.displayName ?? 'Someone';
    return ProfileGridCard(
      name: name,
      age: user.age,
      photoUrl: user.primaryPhotoUrl,
      distanceMeters: user.distanceMeters,
      lastActiveAt: user.lastActiveAt,
      isOnline: user.isOnline,
      isVerified: user.isVerified,
      colorIndex: index,
      onTap: () => showRadiusSheet<void>(
        context: context,
        builder: (_) => ProfileDetailSheet(
          userId: user.id,
          seed: ProfileSeed(
            name: name,
            age: user.age,
            photoUrl: user.primaryPhotoUrl,
            isOnline: user.isOnline,
            colorIndex: index,
          ),
        ),
      ),
    );
  }

  /// A free reveal or credits already in the wallet need no ad; otherwise
  /// it is Premium or one rewarded ad for this visitor.
  Future<void> _reveal(VisitorsPage page, VisitorCard visitor) async {
    if (page.canRevealWithoutAd) {
      // Credits are shared with chats and the radar, so spending one is
      // asked about. A free reveal exists only for this, so it is not.
      final unlocks = page.unlocks;
      if (unlocks != null && unlocks.freeRemaining == 0) {
        final cost = unlocks.creditCost;
        final ok = await showRadiusConfirm(
          context,
          title: 'Reveal this visitor?',
          message:
              'Uses ${cost == 1 ? '1 credit' : '$cost credits'}. '
              'You have ${unlocks.creditBalance}.',
          confirmLabel: 'Reveal',
        );
        if (!ok) return;
      }
      // A false here means the counts were stale and the server wants an ad
      // after all, so fall through to the offer.
      if (await _unlock(visitor, afterAd: false)) return;
    }
    if (!mounted) return;
    await AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.seeWhoVisitedYouTitle,
      descriptionText: AppString.seeWhoVisitedYouDescription,
      unlockType: RewardedUnlockType.seeWhoVisitedYou,
      onAdEarned: () => _unlock(visitor, afterAd: true),
    );
  }

  /// False only when the server asked for payment (402), so the caller can
  /// offer the ad; every other outcome is reported here.
  Future<bool> _unlock(VisitorCard visitor, {required bool afterAd}) async {
    if (!_revealing.add(visitor.visitId)) return true;
    try {
      final revealed = await ref
          .read(visitorActionsProvider)
          .reveal(visitor.visitId, afterAd: afterAd);
      if (mounted) {
        showRadiusToast(
          context,
          'Revealed ${revealed.user.displayName ?? 'your visitor'}',
          tone: ToastTone.success,
        );
      }
      return true;
    } on EntitlementRequiredException {
      if (afterAd && mounted) {
        showRadiusToast(
          context,
          "That didn't unlock them. Try again in a moment.",
          tone: ToastTone.error,
        );
      }
      return afterAd;
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
      return true;
    } finally {
      _revealing.remove(visitor.visitId);
    }
  }
}
