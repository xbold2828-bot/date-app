import 'package:dating_app/shared/widgets/dialogs/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../core/utils/utils.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/location_sharing_card.dart';
import '../widgets/profile_edit_panel.dart';
import '../widgets/profile_edit_sheets.dart';
import '../widgets/you_gallery.dart';
import '../widgets/you_header.dart';
import './blocked_accounts_screen.dart';
import './premium_screen.dart';

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  // ---------------------------------------------------------------------------
  // Action Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onEditBio(String bio) async {
    final saved = await showEditBioSheet(context, bio);
    if (saved && mounted) _snack('Bio updated successfully');
  }

  Future<void> _onEditVibes(List<String> vibes) async {
    final saved = await showEditVibesSheet(context, vibes);
    if (saved && mounted) _snack('Vibes updated successfully');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _onSignOut() async {

    final confirm = await AppDialogs.commonDialog(
      iconData: Icons.logout,
      iconVectorColor: AppColors.whiteColor,
    context: context, headingText: 'Sign Out', descriptionText: 'Are you sure you want to sign out?', buttonText: 'Sign Out',
      isShowTwoButtons: true,
    );

    if (confirm == true && mounted) {
      await ref.read(pushRegistrarProvider).stop();
      await AuthService().signOut();

      if (!mounted) return;
      _navigateToLogin();
    }
  }

  Future<void> _onDeleteAccount() async {
    final confirm = await _showActionDialog(
      title: 'Delete Account',
      content: 'This will permanently delete your account and all data. This cannot be undone.',
      actionText: 'Delete',
      actionColor: AppColors.danger,
    );

    if (confirm == true && mounted) {
      await ref.read(pushRegistrarProvider).stop();
      try {
        await ref.read(profileRepositoryProvider).deleteAccount();
      } catch (_) {
        // Handle error if necessary
      }
      await AuthService().signOut();

      if (!mounted) return;
      _navigateToLogin();
    }
  }

  Future<bool?> _showActionDialog({
    required String title,
    required String content,
    required String actionText,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(color: actionColor, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: AppColors.textGrey, height: 1.4)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor.withValues(alpha: 0.1),
              foregroundColor: actionColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {

    context.go(AppRoutes.login);
  }

  // ---------------------------------------------------------------------------
  // Build Method
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;

    if (me == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final stats = ref.watch(myProfileStatsProvider).valueOrNull;
    final friends = ref.watch(activeConversationCountProvider);
    final tagLabels = ref.watch(tagLabelsProvider).valueOrNull ?? const {};

    final primaryPhotoUrl = _getPrimaryPhotoUrl(me.primaryPhotoId);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Wordmark(),
          ),

          YouHeader(me: me, avatarUrl: primaryPhotoUrl),
          spacerH(20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: LocationSharingCard(),
          ),
          spacerH(20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileMetricsRow(
              visits: stats?.profileViews,
              likes: stats?.likesReceived,
              friends: friends,
            ),
          ),
          spacerH(26),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: YouGallery(primaryPhotoId: me.primaryPhotoId),
          ),
          spacerH(26),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProfileSectionCard(
              label: 'MY VIBE',
              onEdit: () => _onEditVibes(me.profile.personalityTags),
              child: me.profile.personalityTags.isEmpty
                  ? Text('Nothing picked yet.', style: AppTextStyles.caption)
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final vibe in me.profile.personalityTags)
                    TagPill(
                      label: tagLabels[vibe] ?? humanizeSlug(vibe),
                      tone: TagTone.neutral,
                    ),
                ],
              ),
            ),
          ),
          spacerH(16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProfileSectionCard(
              label: 'BIO',
              onEdit: () => _onEditBio(me.profile.bio ?? ''),
              child: Text(
                (me.profile.bio ?? '').trim().isEmpty
                    ? 'Say something worth replying to.'
                    : me.profile.bio!,
                style: AppTextStyles.body.copyWith(
                  height: 1.5,
                  color: (me.profile.bio ?? '').trim().isEmpty
                      ? AppColors.textGrey
                      : AppColors.textDark,
                ),
              ),
            ),
          ),
          spacerH(16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileEditPanel(me: me),
          ),
          spacerH(16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _VerificationCard(isVerified: me.verified),
          ),
          spacerH(16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PremiumCard(isPremium: me.premium.isActive),
          ),
          spacerH(24),

          // Settings & Actions
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DarkModeTile(),
          ),
          spacerH(12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MenuTile(
              icon: Icons.block_outlined,
              label: 'Blocked accounts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
              ),
            ),
          ),
          spacerH(12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MenuTile(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              onTap: _onSignOut,
            ),
          ),
          spacerH(32),

          Center(
            child: GestureDetector(
              onTap: _onDeleteAccount,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.danger.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          spacerH(80),
        ],
      ),
    ).withGlobalBackHandler(context);
  }

  String? _getPrimaryPhotoUrl(String? primaryId) {
    if (primaryId == null) return null;
    final media = ref.watch(myMediaProvider).valueOrNull ?? const [];

    for (final asset in media) {
      if (asset.id == primaryId) return asset.url;
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Extracted Widgets for Premium UI & Better Performance
// -----------------------------------------------------------------------------

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.label,
    required this.onEdit,
    required this.child,
  });

  final String label;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark.withValues(alpha: 0.8),
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit ${label.toLowerCase()}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          spacerH(16),
          child,
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.textDark),
            ),
            spacerW(16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

class _DarkModeTile extends ConsumerWidget {
  const _DarkModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDarkMode(context, ref.watch(themeModeProvider));

    return Semantics(
      toggled: dark,
      label: 'Dark mode',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 20,
                color: AppColors.textDark,
              ),
            ),
            spacerW(16),
            Expanded(
              child: Text(
                'Dark mode',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch.adaptive(
              value: dark,
              activeColor: AppColors.primary,
              onChanged: (on) => ref.read(themeModeProvider.notifier).toggle(dark: on),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isVerified ? AppColors.ok : Colors.black)
                .withValues(alpha: isVerified ? 0.08 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isVerified
              ? AppColors.ok.withValues(alpha: 0.25)
              : AppColors.inputBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isVerified
                  ? LinearGradient(
                colors: [
                  AppColors.ok.withValues(alpha: 0.2),
                  AppColors.ok.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isVerified ? null : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 24,
              color: isVerified ? AppColors.ok : AppColors.iconMuted,
            ),
          ),
          spacerW(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT VERIFICATION',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textGrey,
                  ),
                ),
                spacerH(4),
                Text(
                  isVerified ? 'Identity Verified' : 'Not verified yet',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                spacerH(2),
                Text(
                  isVerified
                      ? 'Your profile is trusted and visible to others.'
                      : 'Verify to unlock the full experience.',
                  style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          if (isVerified) const VerificationTick(size: 26),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1F63), Color(0xFF1A123B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.premium.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.premium,
                      AppColors.premium.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium_rounded : Icons.star_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              spacerW(14),
              const Expanded(
                child: Text(
                  'Cozune Premium',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onImage,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          spacerH(12),
          Text(
            isPremium
                ? 'Unlimited radius, every filter, and no ads.'
                : 'See everyone nearby, filter everything, and drop the ads.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          spacerH(20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                backgroundColor: AppColors.onImage,
                foregroundColor: AppColors.premiumDeep,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isPremium ? 'Manage Subscription' : 'See what you get',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}