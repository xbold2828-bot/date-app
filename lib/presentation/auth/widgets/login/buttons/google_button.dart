import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/constants/static_assets/app_vectors.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import '../../../../../providers/auth/login_provider/login_provider.dart';

class GoogleButton extends ConsumerWidget {
  const GoogleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(loginProvider.select((s) => s.isGoogleLoading));
    final enabled = ref.watch(loginProvider.select((s) => s.canUseGoogle));

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Continue with Google, working' : 'Continue with Google',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || busy ? 1 : 0.55,
        child: Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.inputBorder, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: (busy || !enabled) ? null : onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Center(
                child: busy
                    ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.textDark,
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppVectors.googleG,
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}