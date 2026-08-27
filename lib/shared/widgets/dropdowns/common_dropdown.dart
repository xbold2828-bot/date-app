import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_styles.dart';

class CommonDropdownField<T> extends StatelessWidget {
  final T? value;
  final String hintText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  // Validation
  final String? Function(T?)? validator;

  // Styling
  final Widget? prefixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? border;
  final Color? fillColor;
  final bool filled;

  const CommonDropdownField({
    super.key,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.contentPadding,
    this.border,
    this.fillColor,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.greyColor;

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,color: Colors.black87,),
      style: context.appTextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Colors.grey,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: context.appTextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: color,
        ),
        prefixIcon: prefixIcon,
        filled: filled,
        fillColor: fillColor,
        contentPadding: contentPadding ??
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(width: 1.r, color: color),
            ),
        enabledBorder: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(width: 1.r, color: color),
            ),
        focusedBorder: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(width: 1.5.r, color: color),
            ),
      ),
    );
  }
}
