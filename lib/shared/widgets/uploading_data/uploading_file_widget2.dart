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

class UploadingFileWidget2 extends StatelessWidget {
  final VoidCallback onBrowseTap;
  final String? selectedFileName;
  final String? selectedFilePath; // ✅ Added
  final String supportedFormatsText;
  final VoidCallback onRemoveFile;
  final double? height;

  const UploadingFileWidget2({
    super.key,
    required this.onBrowseTap,
    this.selectedFileName,
    this.selectedFilePath, // ✅ Added
    this.supportedFormatsText = 'PDF, DOC, or DOCX (Max 5 MB)',
    required this.onRemoveFile,
    this.height,
  });

  Future<void> _confirmDeletion(BuildContext context) async {
    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            title: const Text("Remove File"),
            content: Text(
              "Are you sure you want to remove \"$selectedFileName\"?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Remove",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) onRemoveFile();
  }

  /// ✅ Navigate to document viewer
  void _openViewer(BuildContext context) {
    if (selectedFilePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerPage(fileUrl: selectedFilePath!),
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
                    // ✅ Tap to view hint
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
              // ✅ Delete tap is isolated — doesn't trigger viewer
              InkWell(
                onTap: () => _confirmDeletion(context),
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
          height: 189.h,
          child: Padding(
            padding: EdgeInsets.all(20.r).copyWith(top: 30.h, bottom: 30.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                spacerH(10),
                AppText(
                  text: 'Choose a file from your device.',
                  fontSize: 15,
                  color: colorScheme.surface.withValues(alpha: 0.87),
                  fontWeight: FontWeight.w400,
                ),
                spacerH(5),
                AppText(
                  text: supportedFormatsText,
                  fontSize: 13,
                  color: colorScheme.surface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
                spacerH(16),
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
