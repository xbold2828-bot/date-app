import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../common/widgets/widgets.dart';
import 'live_location_line.dart';

class YouHeader extends StatelessWidget {
  const YouHeader({
    super.key,
    required this.me,
    required this.avatarUrl,
    this.isCurrentUser = true,
  });

  final MeUser me;
  final String? avatarUrl;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final isPremium = me.premium.isActive;
    final isVerified = me.verified;

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPremium
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.premium,
                  AppColors.premium.withValues(alpha: 0.55),
                ],
              )
                  : null,
              border: !isPremium
                  ? Border.all(
                color: isVerified ? AppColors.ok : AppColors.inputBorder,
                width: 2,
              )
                  : null,
              boxShadow: isPremium
                  ? [
                BoxShadow(
                  color: AppColors.premium.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
                  : null,
            ),
            child: PremiumAvatar(
              isPremium: isPremium,
              isCurrentUser: isCurrentUser,
              ringColor: isVerified ? AppColors.ok : AppColors.inputBorder,
              child: avatarUrl != null
                  ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: AppColors.inputBorder.withValues(alpha: 0.3),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.person,
                  size: 40,
                  color: AppColors.onImage,
                ),
              )
                  : const Icon(Icons.person, size: 40, color: AppColors.onImage),
            ),
          ),

          const SizedBox(height: 14),

          NameWithTick(
            name: me.age != null
                ? '${me.displayName ?? 'You'}, ${me.age}'
                : (me.displayName ?? 'You'),
            isVerified: isVerified,
            style: AppTextStyles.title.copyWith(
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
            tickSize: 19,
            mainAxisAlignment: MainAxisAlignment.center,
          ),

          if (isPremium && isCurrentUser) ...[
            const SizedBox(height: 10),
            const _PremiumPill(),
          ],

          const SizedBox(height: 10),

          LiveLocationLine(
            city: me.location?.city,
            anchorLatitude: me.location?.latitude,
            anchorLongitude: me.location?.longitude,
          ),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.premium.withValues(alpha: 0.18),
            AppColors.premiumTint,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.premium.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.premium.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 14, color: AppColors.premium),
          const SizedBox(width: 6),
          Text(
            'PREMIUM',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.premiumInk,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ],
      ),
    );
  }
}