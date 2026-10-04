import 'package:dating_app/shared/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        const Center(child: Wordmark(size: 26)),
        // const Center(child: EmptyWidget()),
        Center(child: staticImage(url: AppAnimation.radarGif, h: 200.h)),

        const VerifiedBadge(),
        spacerH(20),
        Text(
          'Meet exactly\nwho you want.',
          style: AppTextStyles.display.copyWith(
            height: 1.1,
            fontSize: 42,
            fontWeight: FontWeight.w600,
          ),
        ),
        spacerH(16),
        Text(
          'An exclusive community of real people. No endless swiping, just meaningful connections.',
          style: AppTextStyles.bodyMuted.copyWith(height: 1.4, fontSize: 15),
        ),
        spacerH(40),
      ],
    );
  }
}


class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand gradient: blue -> purple (theme-aware via AppColors getters).
    final brandGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [AppColors.primary, AppColors.premium],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            AppColors.card.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.inputBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textGrey.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in a brand-gradient circle
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: brandGradient,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 14,
              color: AppColors.onAccent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '18+',
            style: AppTextStyles.eyebrow.copyWith(
              // color: AppColors.textDark,
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
              color: AppColors.textGrey.withValues(alpha: 0.7),
            ),
          ),
          Text(
            'VERIFIED ONLY',
            style: AppTextStyles.eyebrow.copyWith(
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