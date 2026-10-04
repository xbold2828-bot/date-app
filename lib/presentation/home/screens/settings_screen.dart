import 'package:dating_app/core/utils/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/location_sharing_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_sharing_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/dialogs/all_dialogs/radius_dialog.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../common/widgets/widgets.dart';
import 'blocked_accounts_screen.dart';
import 'premium_screen.dart';

/// Everything about the account that is not the profile itself.
///
/// These used to be a column of cards under the photos on the "You" tab —
/// premium, verification, dark mode, blocked accounts, sign out — so the
/// profile read as a settings page with a picture on top. They are rows here,
/// grouped by what they are about, one tap from the menu.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  /// Shared exit path for sign out and delete account.
  ///
  /// Everything is captured BEFORE any await, because signOut() changes auth
  /// state and this widget may be disposed mid-way (`ref`/`context`/`mounted`
  /// are unsafe after that).
  Future<void> _endSession({
    required String tag,
    required Future<void> Function() work,
  }) async {
    if (_busy) {
      AppLogger.d('[$tag] ignored, already running');
      return;
    }
    _busy = true;

    final router = GoRouter.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final container = ProviderScope.containerOf(context, listen: false);

    AppLogger.d('[$tag] start');

    try {
      try {
        AppLoader.show();
      } catch (e) {
        AppLogger.d('[$tag] loader show failed: $e');
      }

      try {
        await work();
        AppLogger.d('[$tag] work done');
      } catch (e, st) {
        AppLogger.d('[$tag] ERROR in work: $e\n$st');
      }

      try {
        container.invalidate(meProvider);
      } catch (e) {
        AppLogger.d('[$tag] invalidate failed: $e');
      }

      AppLoader.hide();
      AppLogger.d('[$tag] loader hidden');

      rootNavigator.popUntil((route) => route.isFirst);
      router.go(AppRoutes.login);
      AppLogger.d('[$tag] router.go(login) called');
    } finally {
      _busy = false;
    }
  }

  Future<void> _onSignOut() async {
    AppLogger.d('[signOut] tapped');

    final confirm = await AppDialogs.commonDialog2(
      context: context,
      headingText: 'Sign out of cozune?',
      descriptionText: 'Your profile and chats stay as they are. You just '
          "won't get notifications until you sign back in.",
      buttonText: 'Sign out',
      isShowTwoButtons: true,
      destructive: true,
    );

    AppLogger.d('[signOut] dialog result: $confirm, mounted: $mounted');
    if (confirm != true || !mounted) return;

    final push = ref.read(pushRegistrarProvider);

    await _endSession(
      tag: 'signOut',
      work: () async {
        await push.stop();
        AppLogger.d('[signOut] push stopped');
        await AuthService().signOut();
        AppLogger.d('[signOut] AuthService.signOut done');
      },
    );
  }

  Future<void> _onDeleteAccount() async {
    AppLogger.d('[delete] tapped');

    final confirm = await showRadiusConfirm(
      context,
      title: 'Delete your account?',
      message: 'This permanently deletes your account and all of its data. '
          'It cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );

    AppLogger.d('[delete] dialog result: $confirm, mounted: $mounted');
    if (!confirm || !mounted) return;

    final push = ref.read(pushRegistrarProvider);
    final profileRepo = ref.read(profileRepositoryProvider);

    await _endSession(
      tag: 'delete',
      work: () async {
        await push.stop();
        AppLogger.d('[delete] push stopped');
        try {
          await profileRepo.deleteAccount();
          AppLogger.d('[delete] account deleted');
        } catch (e) {
          AppLogger.d('[delete] deleteAccount failed: $e');
        }
        await AuthService().signOut();
        AppLogger.d('[delete] AuthService.signOut done');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    final isPremium = me?.premium.isActive ?? false;
    final verified = me?.verified ?? false;
    final sharing =
        ref.watch(locationSharingProvider).valueOrNull ??
            me?.locationSharing ??
            LocationSharing.initial;
    final dark = isDarkMode(context, ref.watch(themeModeProvider));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: BackChevron(onTap: () => Navigator.of(context).maybePop()),
        titleSpacing: 0,
        title: Text('Settings', style: AppTextStyles.title),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _Section('Membership'),
          _Row(
            icon: Icons.workspace_premium_outlined,
            iconColor: AppColors.premium,
            title: 'cozune Premium',
            subtitle: isPremium
                ? 'Active — manage your plan'
                : 'Unlimited likes, every filter, no ads',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
          ),
          const _Section('Profile'),
          _Row(
            icon: Icons.verified_outlined,
            title: 'Verification',
            subtitle: verified
                ? 'Your profile shows the verified tick'
                : 'Not verified yet',
            trailing: verified ? const VerificationTick(size: 22) : null,
          ),
          const _Section('Privacy'),
          _Row(
            icon: sharing.isSharingWithAnyone
                ? Icons.near_me_rounded
                : Icons.near_me_disabled_outlined,
            title: 'Live location',
            subtitle: _sharingLine(sharing),
            onTap: () => context.push(AppRoutes.locationSharing),
          ),
          _Row(
            icon: Icons.block_outlined,
            title: 'Blocked accounts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
            ),
          ),
          const _Section('Display'),
          _Row(
            icon: dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            title: 'Dark mode',
            toggled: dark,
            trailing: Switch.adaptive(
              value: dark,
              onChanged: (on) =>
                  ref.read(themeModeProvider.notifier).toggle(dark: on),
            ),
            onTap: () =>
                ref.read(themeModeProvider.notifier).toggle(dark: !dark),
          ),
          const _Section('Account'),
          _Row(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            showChevron: false,
            onTap: _onSignOut,
          ),
          _Row(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account',
            danger: true,
            showChevron: false,
            onTap: _onDeleteAccount,
          ),
        ],
      ),
    );
  }

  static String _sharingLine(LocationSharing s) {
    if (!s.enabled) return "Off — you're not on anyone's map";
    return switch (s.audience) {
      LocationAudience.everyone => 'Shared with everyone',
      LocationAudience.friends => 'Shared with all friends',
      LocationAudience.selected =>
      s.allowedUserIds.isEmpty
          ? "Off — you're not on anyone's map"
          : 'Shared with ${s.selectedCount} '
          '${s.selectedCount == 1 ? 'friend' : 'friends'}',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 6),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 13.5,
            color: AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.danger = false,
    this.showChevron = true,
    this.toggled,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final bool danger;
  final bool showChevron;

  /// Set for a switch row, so it is announced as one.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.danger : AppColors.textDark;
    return Semantics(
      button: onTap != null && toggled == null,
      toggled: toggled,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 24, color: danger ? ink : (iconColor ?? ink)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 15.5,
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: AppTextStyles.caption.copyWith(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ] else if (showChevron && onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.iconMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}