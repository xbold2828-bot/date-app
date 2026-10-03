import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import '../screens/premium_screen.dart';

/// Shown when a free member taps a locked filter.
///
/// Rewarded ads mint *credits*, and credits only pay for discovery reveals —
/// there is no credit path to a premium filter today, so this deliberately does
/// not offer "watch an ad" as a way to unlock one. Adding that would need a
/// server-side rule letting credits buy filter access.
Future<void> showPremiumFilterPrompt(
  BuildContext context, {
  required String filterName,
}) =>
    showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                '$filterName is a Premium filter',
                style: AppTextStyles.title,
              ),
            ),
            const SizedBox(height: 12),
            // Says what stays free, not just what costs. Someone who declines
            // should still know the app works for them.
            Text(
              'Premium narrows the circle down to who is around right now. '
              'Distance, who you see, age and intent stay free.',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 24),
            RadiusButton(
              label: 'See Premium',
              kind: RadiusButtonKind.premium,
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  'Not now',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
