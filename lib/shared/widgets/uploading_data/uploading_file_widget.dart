import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/static_assets/app_vectors.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';
import '../buttons/common_small_button.dart';
import '../document_viewer/document_viewer_widget.dart';

class UploadingFileWidget extends StatelessWidget {
  final VoidCallback onBrowseTap;
  final String? selectedFileName;
  final String? selectedFilePath; // ✅ Added: local file path for viewer
  final String supportedFormatsText;
  final VoidCallback onRemoveFile;

  const UploadingFileWidget({
    super.key,
    required this.onBrowseTap,
    this.selectedFileName,
    this.selectedFilePath, // ✅ Added
    this.supportedFormatsText = 'Upload PDF, JPG, JPEG',
    required this.onRemoveFile,
  });

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            "Remove File",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            "Are you sure you want to remove this file?\n'${selectedFileName ?? 'this file'}'",
            style: TextStyle(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "Cancel",
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Remove",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      onRemoveFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: selectedFileName != null
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      sizeCurve: Curves.easeInOut,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,

      // ── File selected state ──────────────────────────────────────────────
      secondChild: InkWell(
        onTap: () {
          // ✅ Only navigate if we have a path to view
          if (selectedFilePath != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DocumentViewerPage(fileUrl: selectedFilePath!),
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          height: 50.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              width: 1.r,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _fileIcon(selectedFileName),
              spacerW(10),
              Expanded(
                child: AppText(
                  text: selectedFileName ?? "",
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface.withValues(alpha: 0.87),
                  isEllipsis: true,
                ),
              ),
              spacerW(10),
              InkWell(
                onTap: () => _showDeleteConfirmation(context),
                child: SvgPicture.asset(AppVectors.deleteIcon),
              ),
            ],
          ),
        ),
      ),

      // ── No file state ────────────────────────────────────────────────────
      firstChild: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          strokeWidth: 1.5,
          dashPattern: const [6, 6],
          radius: Radius.circular(8.r),
          color: colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(AppVectors.uploadingIcon),
                spacerH(10),
                AppText(
                  text: supportedFormatsText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                spacerH(5),
                AppText(
                  text: 'No file selected',
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
                spacerH(10),
                CommonSmallButton(text: "Browse File", onTap: onBrowseTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileIcon(String? fileName) {
    if (fileName == null || fileName.isEmpty) return const SizedBox.shrink();
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return SvgPicture.asset(AppVectors.pdfIcon);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const FaIcon(FontAwesomeIcons.image);
      default:
        return const FaIcon(FontAwesomeIcons.fileLines);
    }
  }
}
