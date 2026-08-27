import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/enums/file_pick_option.dart';
import '../../../../core/utils/utils.dart';
import '../../app_text.dart';
import '../../common_title_description.dart';

class UploadFileSheet extends StatelessWidget {
  final bool isImagePicker;

  const UploadFileSheet({super.key, this.isImagePicker = false});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spacerH(10),

            const CommonTitleDescription(
              title: "Upload document",
              description: "Choose how you want to upload your file",
              titleFontSize: 20,
            ),

            if (!kIsWeb) spacerH(20),

            /// 📷 Camera Option
            if (!kIsWeb)
              _BottomSheetOptionTile(
                faIcon: FontAwesomeIcons.camera,
                title: 'Camera',
                subtitle: 'Click a photo using camera',
                onTap: () => context.pop(FilePickOption.camera),
              ),

            spacerH(15),

            /// 🖼️ Gallery Option
            _BottomSheetOptionTile(
              faIcon: FontAwesomeIcons.image,
              title: 'Gallery',
              subtitle: 'Select a photo from gallery',
              onTap: () => context.pop(FilePickOption.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetOptionTile extends StatelessWidget {
  final IconData? icon;
  final FaIconData? faIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomSheetOptionTile({
    this.icon,
    this.faIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null)
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(icon, size: 22.r)),
                ),

              if (faIcon != null)
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: FaIcon(faIcon, size: 22.r)),
                ),

              spacerW(15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: title,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    spacerH(2),

                    AppText(
                      text: subtitle,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.surface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
