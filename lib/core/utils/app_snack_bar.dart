import 'package:flutter/material.dart';

import '../../main.dart';

abstract final class AppSnackBar {
  // ── Dedup guard ──────────────────────────────────────────────────────────
  // _currentKey holds an identity for whatever snackbar is currently on
  // screen (built from title + message). _isShowing tracks whether that
  // snackbar is still visible. While a snackbar is showing, any request for
  // the SAME message is ignored outright (not queued). Once the visible
  // snackbar closes — dismissed, timed out, or replaced — the guard clears,
  // so the same message is free to show again the next time it's triggered.
  static String? _currentKey;
  static bool _isShowing = false;

  static String _buildKey({required String message, String? title}) {
    return '${title ?? ''}::$message';
  }

  static void showCustomSnackBar({
    required String message,
    String? title,
    bool isError = false,
    Color? bgColor,
    IconData? icon,
    int? seconds,
  }) {
    final messenger = scaffoldMessengerKey.currentState;

    if (messenger == null) return;

    final key = _buildKey(message: message, title: title);

    // If this exact snackbar is already showing, ignore the new trigger
    // completely — don't restart it, don't queue it.
    if (_isShowing && _currentKey == key) {
      return;
    }

    // Remove existing snackBar (different message replacing the old one).
    messenger.hideCurrentSnackBar();

    _currentKey = key;
    _isShowing = true;

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        duration: Duration(seconds: seconds ?? 2),
        backgroundColor: bgColor ?? (isError ? Colors.red : Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white),
            if (icon != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // When this specific snackbar closes (finished, dismissed, or replaced),
    // clear the guard — but only if nothing newer has already taken over
    // _currentKey in the meantime.
    controller.closed.then((_) {
      if (_currentKey == key) {
        _isShowing = false;
        _currentKey = null;
      }
    });
  }

  static void showSuccessSnackBar({
    required String message,
    String? title,
    Color? bgColor,
    int? seconds,
  }) {
    showCustomSnackBar(
      icon: Icons.check,
      message: message,
      bgColor: bgColor,
      isError: false,
      title: title,
      seconds: seconds,
    );
  }

  static void showErrorSnackBar({
    required String message,
    String? title,
    Color? bgColor,
    int? seconds,
  }) {
    showCustomSnackBar(
      icon: Icons.error,
      message: message,
      bgColor: bgColor,
      isError: true,
      title: title,
      seconds: seconds,
    );
  }

  static void showWarningSnackBar({
    required String message,
    String? title,
    Color? bgColor,
    int? seconds,
  }) {
    showCustomSnackBar(
      icon: Icons.info_outline,
      message: message,
      bgColor: bgColor ?? Colors.black,
      isError: false,
      title: title,
      seconds: seconds,
    );
  }
}

// import 'package:flutter/material.dart';
// import '../../main.dart';
//
// abstract final class AppSnackBar {
//
//   static void showCustomSnackBar({
//     required String message,
//     String? title,
//     bool isError = false,
//     Color? bgColor,
//     IconData? icon,
//     int? seconds,
//   }) {
//     final messenger = scaffoldMessengerKey.currentState;
//
//     if (messenger == null) return;
//
//     // Remove existing snackBar
//     messenger.hideCurrentSnackBar();
//
//     messenger.showSnackBar(
//       SnackBar(
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(10),
//         duration: Duration(seconds: seconds ?? 2),
//         backgroundColor:
//         bgColor ?? (isError ? Colors.red : Colors.green),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//         content: Row(
//           children: [
//             if (icon != null)
//               Icon(icon, color: Colors.white),
//             if (icon != null)
//               const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   if (title != null)
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                   Text(
//                     message,
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   static void showSuccessSnackBar({
//     required String message,
//     String? title,
//     Color? bgColor,
//     int? seconds,
//   }) {
//     showCustomSnackBar(
//       icon: Icons.check,
//       message: message,
//       bgColor: bgColor,
//       isError: false,
//       title: title,
//       seconds: seconds,
//     );
//   }
//
//   static void showErrorSnackBar({
//     required String message,
//     String? title,
//     Color? bgColor,
//     int? seconds,
//   }) {
//     showCustomSnackBar(
//       icon: Icons.error,
//       message: message,
//       bgColor: bgColor,
//       isError: true,
//       title: title,
//       seconds: seconds,
//     );
//   }
//
//   static void showWarningSnackBar({
//     required String message,
//     String? title,
//     Color? bgColor,
//     int? seconds,
//   }) {
//     showCustomSnackBar(
//       icon: Icons.info_outline,
//       message: message,
//       bgColor: bgColor ?? Colors.black,
//       isError: false,
//       title: title,
//       seconds: seconds,
//     );
//   }
// }
