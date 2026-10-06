import 'package:flutter/material.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/constants/static_assets/app_animation.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/utils/utils.dart';

import '../../../common/widgets/step_header.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Wordmark(size: 25)),
        Center(child: staticImage(url: AppAnimation.radarGif, h: 180)),
        const VerifiedBadge(),
        spacerH(15),
        Text(
          'Meet exactly\nwho you want.',
          style: AppTextStyles.display.copyWith(
            height: 1.1,
            fontSize: 34,
            fontWeight: FontWeight.w600,
          ),
        ),
        spacerH(10),
        Text(
          'An exclusive community of real people. No endless swiping, just meaningful connections.',
          style: AppTextStyles.bodyMuted.copyWith(height: 1.4, fontSize: 13),
        ),
        spacerH(30),
      ],
    );
  }
}


class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.inputBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in a soft blue circle
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '18+',
            style: AppTextStyles.eyebrow.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          // Dot separator
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textGrey.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'VERIFIED ONLY',
            style: AppTextStyles.eyebrow.copyWith(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}