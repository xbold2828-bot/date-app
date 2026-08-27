import 'package:dating_app/shared/widgets/textfield/common_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/static_assets/app_vectors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import 'app_text.dart';

class CommonTextFieldHeading extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String titleHintText;
  final double? titleFontSize;

  // Text
  final String hintText;
  final String? labelText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool isTitleHint;

  // Obscure
  final bool isPassword;

  // Validation & callbacks
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  // Icons
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  // Styling
  final TextStyle? textStyle;
  final InputBorder? border;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final bool filled;
  final FontWeight? titleFontWeight;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? titlePadding;

  const CommonTextFieldHeading({
    super.key,
    required this.title,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.titleFontSize,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.titleHintText = "",
    this.readOnly = false,
    this.isTitleHint = false,
    this.enabled = true,
    this.isPassword = false,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.textStyle,
    this.border,
    this.contentPadding,
    this.fillColor,
    this.filled = false,
    this.titleFontWeight,
    this.titlePadding,
  });

  @override
  State<CommonTextFieldHeading> createState() => _CommonTextFieldHeadingState();
}

class _CommonTextFieldHeadingState extends State<CommonTextFieldHeading> {
  bool _showHint = false;

  @override
  Widget build(BuildContext context) {
    // final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.isTitleHint
            ? Row(
                children: [
                  Flexible(
                    child: AppText(
                      text: widget.title,
                      fontSize: widget.titleFontSize??15,
                      fontWeight: widget.titleFontWeight ?? FontWeight.w600,
                    ),
                  ),

                  spacerW(6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showHint = !_showHint;
                      });
                    },
                    child: SvgPicture.asset(AppVectors.infoIcon)
                  ),
                ],
              )
            : Padding(
              padding: widget.titlePadding ?? const EdgeInsets.all(0),
              child: AppText(
                  text: widget.title,
                fontSize: widget.titleFontSize??15,
                  fontWeight: widget.titleFontWeight ?? FontWeight.w600,
                ),
            ),

        spacerH(5),

        // 🔹 TextField
        CommonTextField(
          focusNode: widget.focusNode,
          controller: widget.controller,
          hintText: widget.hintText,
          labelText: widget.labelText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          isPassword: widget.isPassword,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTap: widget.onTap,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          textStyle: widget.textStyle,
          border: widget.border,
          contentPadding: widget.contentPadding,
          fillColor: widget.fillColor,
          filled: widget.filled,
        ),

        if (widget.isTitleHint) ...[
          spacerH(5),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showHint
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: AppText(
              text: widget.titleHintText,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: isLightTheme? const Color(0xff374151) :AppColors.whiteColor
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
