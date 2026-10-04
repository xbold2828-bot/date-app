import 'package:flutter/material.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.inputBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.inputBorder, thickness: 1)),
      ],
    );
  }
}