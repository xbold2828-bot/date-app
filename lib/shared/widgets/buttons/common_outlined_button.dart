import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';

class CommonOutlinedButton extends StatefulWidget {
  final String text;
  final Color? textColor;
  final double? width;
  final Color? borderColor;
  final VoidCallback? onClick;
  final double? height;
  final FontWeight? fontWeight;
  final double? fontSize;
  final String? vectorIcon;
  final double? buttonRadius;
  final bool isDisableButton;
  final bool isLoading;
  final Color? isPressedColor;

  const CommonOutlinedButton({
    super.key,
    required this.text,
    required this.onClick,
    this.textColor,
    this.borderColor,
    this.height,
    this.width,
    this.vectorIcon,
    this.buttonRadius,
    this.fontSize,
    this.fontWeight,
    this.isLoading = false,
    this.isDisableButton = false,
    this.isPressedColor,
  });

  @override
  State<CommonOutlinedButton> createState() => _CommonOutlinedButtonState();
}

class _CommonOutlinedButtonState extends State<CommonOutlinedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.primary.withValues(alpha: 0.01);
    final radius = (widget.buttonRadius ?? 8).r;
    final activeBorderColor = widget.borderColor ?? colorScheme.primary;
    final activeTextColor = widget.textColor ?? colorScheme.primary;
    return Material(
      color: _isPressed
          ? colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: widget.isLoading || widget.isDisableButton
            ? null
            : widget.onClick,
        onHighlightChanged: (value) {
          setState(() => _isPressed = value);
        },
        child: Container(
          width: (widget.width)?.w ?? double.infinity,
          height: (widget.height ?? 50).h,
          padding: EdgeInsets.all(5.r),
          decoration: BoxDecoration(
            color: widget.isDisableButton
                ? Colors.grey.shade500
                : _isPressed
                ? (widget.isPressedColor ??
                      colorScheme.primary.withValues(alpha: 0.3))
                : borderColor,
            border: Border.all(width: 1.r, color: activeBorderColor),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: widget.isLoading
                ? CircularProgressIndicator(color: colorScheme.onPrimary)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.vectorIcon != null) ...[
                        SvgPicture.asset(widget.vectorIcon!),
                        spacerW(10),
                      ],
                      AppText(
                        text: widget.text,
                        fontSize: widget.fontSize ?? 15,
                        color: activeTextColor,
                        fontWeight: widget.fontWeight ?? FontWeight.w700,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
