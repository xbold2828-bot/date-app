import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/location_sharing_card.dart';
import '../widgets/profile_edit_panel.dart';
import '../widgets/profile_edit_sheets.dart';
import '../widgets/you_gallery.dart';
import '../widgets/you_header.dart';
import './blocked_accounts_screen.dart';
import './premium_screen.dart';

/// The "Me" tab.
///
/// Composition only. Everything with state of its own lives beside it in
/// `../widgets/`: the header and its animated premium ring, the photo gallery,
/// the device-local location line, and the editor for the onboarding answers.
/// This file's job is the order those appear in and the two account actions at
/// the bottom.
class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  Future<void> _onEditBio(String bio) async {
    final saved = await showEditBioSheet(context, bio);
    if (saved && mounted) _snack('Bio updated');
  }

  Future<void> _onEditVibes(List<String> vibes) async {
    final saved = await showEditVibesSheet(context, vibes);
    if (saved && mounted) _snack('Vibe updated');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Sign Out',
            style: TextStyle(color: AppColors.textDark)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _onDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.red)),
        content: Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(profileRepositoryProvider).deleteAccount();
      } catch (_) {
        // Even if the server call fails, sign out locally.
      }
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final stats = ref.watch(myProfileStatsProvider).valueOrNull;
    // Friends is counted here, from the inbox, rather than fetched — see
    // `activeConversationCountProvider`.
    final friends = ref.watch(activeConversationCountProvider);
    final tagLabels = ref.watch(tagLabelsProvider).valueOrNull ?? const {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.radio_button_checked,
                    size: 20, color: AppColors.textDark),
                const SizedBox(width: 8),
                Text(
                  'RADIUS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          YouHeader(me: me, avatarUrl: _primaryPhotoUrl(me.primaryPhotoId)),

          const SizedBox(height: 18),

          // Directly under the header, and deliberately.
          //
          // The header ends with the live location line — where the device
          // thinks you are, shown only to you. Who else can see that is the
          // very next question, so it is answered in the very next card
          // instead of being filed away with the account actions at the
          // bottom, where a location control would be found only by somebody
          // already worried enough to go hunting for it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const LocationSharingCard(),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileMetricsRow(
              visits: stats?.profileViews,
              likes: stats?.likesReceived,
              friends: friends,
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: YouGallery(primaryPhotoId: me.primaryPhotoId),
          ),

          const SizedBox(height: 24),

          // My Vibe
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
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
                            // Slugs come back from the API; the catalogue turns
                            // them into words, and `humanizeSlug` covers the
                            // moment before it has loaded.
                            label: tagLabels[vibe] ?? humanizeSlug(vibe),
                            tone: TagTone.neutral,
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Bio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
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

          const SizedBox(height: 12),

          // Everything answered during onboarding, folded away until wanted.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProfileEditPanel(me: me),
          ),

          const SizedBox(height: 12),

          // Account verification
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _VerificationCard(isVerified: me.verified),
          ),

          const SizedBox(height: 12),

          // Radius Premium card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PremiumCard(isPremium: me.premium.isActive),
          ),

          const SizedBox(height: 12),

          // Appearance.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _DarkModeTile(),
          ),

          const SizedBox(height: 12),

          // Blocked accounts.
          //
          // Takes over the "Safety Center" slot, which was a tile that did
          // nothing. This is the only route back from a block: once one lands,
          // that person is gone from the radar, from likes, from their profile
          // and from the inbox, so no other screen has a row left to unblock
          // them from.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.block_outlined,
              label: 'Blocked accounts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BlockedAccountsScreen(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              onTap: _onSignOut,
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: _onDeleteAccount,
              child: Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// URL of the photo marked as the profile picture, if it's loaded and still
  /// present (it may have just been deleted).
  String? _primaryPhotoUrl(String? primaryId) {
    if (primaryId == null) return null;
    for (final asset in ref.watch(myMediaProvider).valueOrNull ?? const []) {
      if (asset.id == primaryId) return asset.url;
    }
    return null;
  }

  /// A titled white card with a pencil in its corner.
  Widget _card({
    required String label,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.label),
              Semantics(
                button: true,
                label: 'Edit ${label.toLowerCase()}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

/// Identity verification status. Says what is true rather than what is hoped:
/// an unverified account is told it is unverified.
/// The 🌙 switch.
///
/// It shows the brightness actually being drawn, not the stored [ThemeMode] —
/// so someone whose phone is already dark finds it on rather than off. Flipping
/// it is an explicit choice, and from that point the app stops following the
/// phone.
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
        // Shorter than a menu tile: a Switch is 48pt of touch target on its
        // own, so the usual 16pt of padding would make this row taller than
        // everything it sits between.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(
              dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 20,
              color: AppColors.textDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Dark mode',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: dark,
              onChanged: (on) =>
                  ref.read(themeModeProvider.notifier).toggle(dark: on),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified
              ? AppColors.ok.withValues(alpha: 0.3)
              : AppColors.inputBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.ok.withValues(alpha: 0.1)
                  : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_outlined,
              size: 18,
              color: isVerified ? AppColors.ok : AppColors.iconMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACCOUNT VERIFICATION',
                    style: AppTextStyles.label.copyWith(fontSize: 10)),
                const SizedBox(height: 2),
                Text(
                  isVerified ? 'Identity Verified' : 'Not verified yet',
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                ),
                Text(
                  isVerified
                      ? 'Your profile is trusted and visible to others.'
                      : 'Verify to unlock the full experience.',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (isVerified) const VerificationTick(size: 20),
        ],
      ),
    );
  }
}

/// The premium card — a receipt when it is active, an offer when it is not.
class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF241A4D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.workspace_premium : Icons.radio_button_checked,
                size: 20,
                color: isPremium ? AppColors.premium : AppColors.primary,
              ),
              const SizedBox(width: 8),
              // Unconstrained text in a Row overflows the card on a narrow
              // screen (and at larger system font scales); let it take the
              // remaining width instead.
              const Expanded(
                child: Text(
                  'cozune Premium',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onImage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Unlimited radius, every filter, and no ads.'
                : 'See everyone nearby, filter everything, and drop the ads.',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onImage,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Text(
                isPremium ? 'Manage Subscription' : 'See what you get',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  // Not textDark: the pill is a fixed white on a fixed violet
                  // card, so its label cannot follow the theme's ink or it
                  // turns white-on-white in dark mode.
                  color: AppColors.premiumDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
