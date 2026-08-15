import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../common/widgets/widgets.dart';
import 'live_location_line.dart';

/// The top of the "Me" tab: photo, name, status, and where you are.
///
/// Everything premium about it is gated on [isCurrentUser], which is true here
/// and only here — see [PremiumAvatar] for why that is a privacy rule rather
/// than a style switch. The verified tick is deliberately *not* gated: it is a
/// claim made to other people, so it renders the same on both surfaces.
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
          PremiumAvatar(
            isPremium: isPremium,
            isCurrentUser: isCurrentUser,
            // With no premium to draw, the ring falls back to the verified
            // green it has always been.
            ringColor: isVerified ? AppColors.ok : AppColors.inputBorder,
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.person, size: 40, color: AppColors.white),
          ),

          const SizedBox(height: 12),

          // Name, age, and the tick — one row, so the badge stays attached to
          // the name at every font scale.
          NameWithTick(
            name: me.age != null
                ? '${me.displayName ?? 'You'}, ${me.age}'
                : (me.displayName ?? 'You'),
            isVerified: isVerified,
            style: AppTextStyles.title,
            tickSize: 19,
            mainAxisAlignment: MainAxisAlignment.center,
          ),

          if (isPremium && isCurrentUser) ...[
            const SizedBox(height: 8),
            const _PremiumPill(),
          ],

          const SizedBox(height: 8),

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

/// The PREMIUM chip under the name. Gold, because [AppColors.gold] means
/// exactly one thing in this app.
class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, size: 13, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            'PREMIUM',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: const Color(0xFF7E5A1C),
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ],
      ),
    );
  }
}
