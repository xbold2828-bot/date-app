import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/utils/utils.dart';
import '../../../../../providers/auth/login_provider/login_provider.dart';

class CountryButton extends ConsumerWidget {
  const CountryButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(loginProvider.select((s) => s.country));

    return Semantics(
      button: true,
      label: 'Country: ${country.name}, ${country.code}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 22)),
                spacerW(8),
                Text(
                  country.code,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
                spacerW(4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}