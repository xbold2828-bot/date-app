import 'package:flutter/material.dart';
import '../../../core/enums/file_pick_option.dart';
import 'all_bottom_sheets/upload_file_sheet.dart';

abstract final class AppBottomSheets {

  static Future<FilePickOption?> showFileSourcePicker({
    required BuildContext context,
    bool dismissible = true,
    bool isImagePicker = false,
  }) {

    return showModalBottomSheet<FilePickOption>(
      context: context,
      isDismissible: dismissible,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return UploadFileSheet(
          isImagePicker: isImagePicker,
        );
      },
    );

  }
}