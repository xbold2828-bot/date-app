import 'package:flutter/material.dart';

import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';

class LoginTerms extends StatelessWidget {
  const LoginTerms({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'By continuing you agree to our Terms\nand Privacy Policy.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textGrey.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}