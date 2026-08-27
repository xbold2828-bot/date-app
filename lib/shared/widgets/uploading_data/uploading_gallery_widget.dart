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

class UploadingGalleryWidget extends StatelessWidget {
  final VoidCallback onBrowseTap;
  final String? selectedFileName;
  final String? selectedFilePath; // ✅ Added
  final String supportedFormatsText;
  final VoidCallback onRemoveFile;
  final double? height;

  const UploadingGalleryWidget({
    super.key,
    required this.onBrowseTap,
    this.selectedFileName,
    this.selectedFilePath, // ✅ Added
    this.supportedFormatsText = 'JPG or PNG (Max 5 MB)',
    required this.onRemoveFile,
    this.height,
  });

  Future<void> _showDeleteDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        title: const Text("Remove Photo"),
        content: Text(
          "Are you sure you want to remove '$selectedFileName'?",
          style: TextStyle(color: colorScheme.primary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: colorScheme.surface)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) onRemoveFile();
  }

  /// ✅ Open viewer only if path is available
  void _openViewer(BuildContext context) {
    if (selectedFilePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerPage(
            fileUrl: selectedFilePath!,
          ),
        ),
      );
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
        onTap: () => _openViewer(context), // ✅ Tap row → open viewer
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: double.infinity,
          height: height ?? 44.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              width: 1.r,
              color: colorScheme.surface.withValues(alpha: 0.15),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _fileIcon(selectedFileName),
              spacerW(10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: selectedFileName ?? "",
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.surface.withValues(alpha: 0.87),
                      isEllipsis: true,
                    ),
                    // ✅ Hint shown only when path is available
                    if (selectedFilePath != null)
                      AppText(
                        text: "Tap to view",
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.primary.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ),
              spacerW(10),
              // ✅ Delete is isolated — doesn't trigger viewer
              InkWell(
                onTap: () => _showDeleteDialog(context),
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
          color: colorScheme.surface.withValues(alpha: 0.15),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(AppVectors.gallery),
                spacerH(10),
                const AppText(
                  text: "Choose a photo from your device",
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                spacerH(5),
                AppText(
                  text: supportedFormatsText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.surface.withValues(alpha: 0.6),
                ),
                spacerH(12),
                CommonSmallButton(
                  text: "Choose from Gallery",
                  onTap: onBrowseTap,
                ),
                spacerH(5),
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
