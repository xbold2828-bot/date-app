import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';

import '../../../../providers/auth/login_provider/login_provider.dart';

class PhoneField extends ConsumerWidget {
  const PhoneField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds only when the allowed digit count changes (country change).
    final digits = ref.watch(loginProvider.select((s) => s.country.digits));

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(digits),
        ],
        style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: '0' * digits,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}