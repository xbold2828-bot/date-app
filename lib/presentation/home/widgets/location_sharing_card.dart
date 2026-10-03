import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/location_sharing_model.dart';
import '../../../providers/location_sharing_provider.dart';

class LocationSharingCard extends ConsumerWidget {
  const LocationSharingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(locationSharingProvider).valueOrNull ?? LocationSharing.initial;
    final on = sharing.isSharingWithAnyone;

    return Semantics(
      button: true,
      label: 'Location sharing. ${_headline(sharing)}. ${_detail(sharing)}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: (on ? AppColors.primary : Colors.black).withValues(alpha: on ? 0.15 : 0.02),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: on ? AppColors.primaryTint : AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: on
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.inputBorder.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(AppRoutes.locationSharing),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: on
                          ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      color: on ? null : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      on ? Icons.near_me_rounded : Icons.near_me_disabled_rounded,
                      size: 22,
                      color: on ? Colors.white : AppColors.iconMuted,
                    ),
                  ),
                  spacerW(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Live location',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: on ? AppColors.primary : AppColors.textGrey,
                          ),
                        ),
                        spacerH(4),
                        Text(
                          _headline(sharing),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: on ? AppColors.primaryInk : AppColors.textDark,
                          ),
                        ),
                        spacerH(2),
                        Text(
                          _detail(sharing),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 13,
                            height: 1.3,
                            color: on
                                ? AppColors.primaryInk.withValues(alpha: 0.7)
                                : AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  spacerW(12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: on ? AppColors.primary : AppColors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Who can see you, in as few words as fit on one line.
  String _headline(LocationSharing sharing) {
    if (!sharing.enabled) return 'Not shared with anyone';
    return switch (sharing.audience) {
      LocationAudience.everyone => 'Shared with everyone',
      LocationAudience.friends => 'Shared with all friends',
      LocationAudience.selected => sharing.allowedUserIds.isEmpty
      // Selected-with-nobody is off in every way that matters, and saying
      // "shared with selected friends" here would be a comfortable lie in
      // the other direction.
          ? 'Not shared with anyone'
          : 'Shared with ${sharing.selectedCount} '
          '${sharing.selectedCount == 1 ? 'friend' : 'friends'}',
    };
  }

  String _detail(LocationSharing sharing) {
    if (!sharing.isSharingWithAnyone) {
      return "You're off the map. Tap to change who can see you.";
    }
    return 'Tap to choose who can see you on the map';
  }
}