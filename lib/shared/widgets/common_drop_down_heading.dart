import 'package:flutter/material.dart';
import '../../core/utils/utils.dart';
import 'app_text.dart';
import 'dropdowns/common_searchable_dropdown.dart';

class CommonDropdownHeading extends StatelessWidget {
  final String title;
  final String hintText;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final TextEditingController? controller;
  final bool onTapRemoveText;
  final bool isCompleteNewName;
  final bool enabled;

  const CommonDropdownHeading({
    super.key,
    this.controller,
    required this.title,
    required this.hintText,
    required this.items,
    this.onTapRemoveText=true,
    this.enabled=true,
    required this.onSelected,
    this.isCompleteNewName=false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          text: title,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        spacerH(5),
        CommonSearchableDropdown<String>(
          isCompleteNewName: isCompleteNewName,
          onTapRemoveText: onTapRemoveText,
          hintText: hintText,
          controller: controller,
          validationTitle: title,
          items: items,
          displayString: (item) => item,
          onSelected: onSelected,
          enabled: enabled,
        ),
      ],
    );
  }
}
