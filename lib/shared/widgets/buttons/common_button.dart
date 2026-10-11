import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/extensions/padding_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadow.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';

class CommonButton extends StatefulWidget {
  final double? height;
  final bool isSmallButton;
  final EdgeInsetsGeometry? internalButtonPadding;
  final bool isLoading;
  final double? spaceBetweenIconAndTitle;
  final double? imageIconSize;
  final double? width;
  final String text;
  final String? semanticLabel;
  final Color? textColor;
  final Color? bgColor;
  final VoidCallback? onClick;
  final bool isDisableButton;
  final FontWeight? fontWeight;
  final String? vectorIcon;
  final IconData? iconData;
  final double? iconDataSize;
  final String? imageIcon;
  final double? buttonRadius;
  final Color iconColor;

  const CommonButton({
    super.key,
    this.height,
    this.width,
    this.internalButtonPadding,
    this.spaceBetweenIconAndTitle,
    required this.text,
    this.semanticLabel,
    this.imageIconSize,
    this.iconData,
    this.imageIcon,
    this.textColor,
    this.bgColor,
    this.vectorIcon,
    this.isLoading = false,
    this.isSmallButton = false,
    this.iconDataSize,
    required this.onClick,
    this.buttonRadius,
    this.fontWeight,
    this.iconColor = AppColors.whiteColor,
    this.isDisableButton = false,
  });

  @override
  State<CommonButton> createState() => _CommonButtonState();
}

class _CommonButtonState extends State<CommonButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDisabled = widget.isDisableButton;
    final bool isInteractive = !isDisabled && !widget.isLoading;
    final radius = (widget.buttonRadius ?? 8).r;

    // --- Solid color logic ---
    Color buttonColor = widget.bgColor ?? AppColors.primary;

    // Handle pressed state opacity
    if (_isPressed) {
      buttonColor = buttonColor.withValues(alpha: 0.8);
    }

    return Semantics(
      button: true,
      enabled: isInteractive,
      label: widget.semanticLabel ?? widget.text,
      value: widget.isLoading ? 'Loading' : null,
      onTap: isInteractive ? widget.onClick : null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: isDisabled ? Colors.grey.shade400 : buttonColor,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: widget.isLoading || widget.isDisableButton
                ? null
                : widget.onClick,
            onHighlightChanged: (value) {
              if (!isDisabled) {
                setState(() => _isPressed = value);
              }
            },
            child: SizedBox(
              width:
              (widget.width)?.w ??
                  (widget.isSmallButton ? null : double.infinity),
              height: (widget.height ?? 50).h,
              child: Padding(
                padding:
                widget.internalButtonPadding ?? const EdgeInsets.all(0),
                child: Center(
                  child: widget.isLoading
                      ? CircularProgressIndicator(color: colorScheme.onPrimary)
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.vectorIcon != null) ...[
                        SvgPicture.asset(
                          widget.vectorIcon!,
                          colorFilter: ColorFilter.mode(
                            widget.iconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        spacerW(widget.spaceBetweenIconAndTitle ?? 10),
                      ],

                      if (widget.iconData != null) ...[
                        Icon(
                          widget.iconData,
                          size: widget.iconDataSize,
                          color: widget.iconColor,
                        ),
                      ],
                      if (widget.imageIcon != null) ...[
                        staticImage(
                          url: widget.imageIcon!,
                          color: widget.iconColor,
                          w: widget.imageIconSize,
                        ),
                        spacerW(widget.spaceBetweenIconAndTitle ?? 10),
                      ],
                      AppText(
                        text: widget.text,
                        fontSize: 15,
                        isEllipsis: true,
                        color: isDisabled
                            ? Colors.white70
                            : widget.textColor ?? colorScheme.onPrimary,
                        fontWeight: widget.fontWeight ?? FontWeight.w700,
                      ).paddingSymmetric(horizontal: 8.w),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommonButton2 extends StatefulWidget {
  final double? height;
  final bool isLoading;
  final double? spaceBetweenIconAndTitle;
  final double? imageIconSize;
  final double? width;
  final String text;
  final String? semanticLabel;
  final Color? textColor;
  final Color? bgColor;
  final VoidCallback? onClick;
  final bool isDisableButton;
  final FontWeight? fontWeight;
  final String? vectorIcon;
  final String? imageIcon;
  final double? buttonRadius;
  final Color? label; // unused but kept for compat
  final bool hasShadow;

  const CommonButton2({
    super.key,
    this.height,
    this.width,
    this.spaceBetweenIconAndTitle,
    required this.text,
    this.semanticLabel,
    this.imageIconSize,
    this.imageIcon,
    this.textColor,
    this.bgColor,
    this.vectorIcon,
    this.isLoading = false,
    required this.onClick,
    this.buttonRadius,
    this.fontWeight,
    this.isDisableButton = false,
    this.label,
    this.hasShadow = true,
  });

  @override
  State<CommonButton2> createState() => _CommonButton2State();
}

class _CommonButton2State extends State<CommonButton2>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.isDisableButton;
    final bool isInteractive = !isDisabled && !widget.isLoading;
    final radius = (widget.buttonRadius ?? 14).r;

    // --- Solid color logic ---
    Color buttonColor = widget.bgColor ?? AppColors.secondary;

    if (_isPressed) {
      buttonColor = buttonColor.withValues(alpha: 0.85);
    }

    return Semantics(
      button: true,
      enabled: isInteractive,
      label: widget.semanticLabel ?? widget.text,
      value: widget.isLoading ? 'Loading' : null,
      onTap: isInteractive ? widget.onClick : null,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: (isDisabled || !widget.hasShadow)
                ? null
                : AppShadow.button,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: isDisabled ? Colors.grey.shade400 : buttonColor,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: widget.isLoading || isDisabled ? null : widget.onClick,
                onHighlightChanged: (v) {
                  if (!isDisabled) {
                    setState(() => _isPressed = v);
                    if (v) {
                      _ctrl.forward();
                    } else {
                      _ctrl.reverse();
                    }
                  }
                },
                child: SizedBox(
                  width: (widget.width)?.w ?? double.infinity,
                  height: (widget.height ?? 52).h,
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.vectorIcon != null) ...[
                          SvgPicture.asset(widget.vectorIcon!),
                          SizedBox(
                            width:
                            widget.spaceBetweenIconAndTitle?.w ??
                                10.w,
                          ),
                        ],
                        if (widget.imageIcon != null) ...[
                          staticImage(
                            url: widget.imageIcon!,
                            w: widget.imageIconSize,
                          ),
                          SizedBox(
                            width:
                            widget.spaceBetweenIconAndTitle?.w ??
                                10.w,
                          ),
                        ],
                        AppText(
                          text: widget.text,
                          fontSize: 15,
                          isEllipsis: true,
                          color: isDisabled
                              ? Colors.white70
                              : widget.textColor ?? Colors.white,
                          fontWeight:
                          widget.fontWeight ?? FontWeight.w700,
                          letterSpacing: 0.2,
                        ).paddingSymmetric(horizontal: 8.w),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}