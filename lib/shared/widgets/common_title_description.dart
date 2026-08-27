import 'package:flutter/material.dart';
import '../../core/utils/utils.dart';
import 'app_text.dart';

class CommonTitleDescription extends StatelessWidget {
  final String title;
  final String description;
  final double? titleFontSize;
  final FontWeight? titleFontWeight;
  final FontWeight? descriptionFontWeight;
  final double? descriptionFontSize;
  final TextAlign? titleAlign;
  final TextAlign? descriptionAlign;
  final Color? titleColor;
  final Color? descriptionColor;
  final bool isColumnCrossAlignCenter;
  final double? spaceBtwTitleDes;

  const CommonTitleDescription({
    super.key,
    required this.title,
    required this.description,
    this.titleFontSize,
    this.descriptionFontSize,
    this.titleAlign,
    this.descriptionAlign,
    this.titleFontWeight,
    this.descriptionFontWeight,
    this.titleColor,
    this.descriptionColor,
    this.isColumnCrossAlignCenter = true,
    this.spaceBtwTitleDes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isColumnCrossAlignCenter
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          AppText(
            text: title,
            fontSize: titleFontSize ?? 22,
            fontWeight: titleFontWeight ?? FontWeight.w600,
            textAlign: titleAlign ?? TextAlign.center,
            color: titleColor ?? colorScheme.onSurface,
          ),
          spacerH(spaceBtwTitleDes ?? 6),
          AppText(
            text: description,
            fontSize: descriptionFontSize ?? 15,
            color:
                descriptionColor ??
                colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: descriptionFontWeight ?? FontWeight.w400,
            textAlign: descriptionAlign ?? TextAlign.center,
          ),
        ],
      ),
    );
  }
}
