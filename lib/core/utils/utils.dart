import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logger/app_logger.dart';
import 'app_snack_bar.dart';

Future<void> openUrl({
  String? url,
  Uri? newUri,
  bool isExternal = false,
  String failureLabel = "Unable to open!",
}) async {
  try {
    Uri? uri = newUri;

    if (uri == null) {
      String rawUrl = (url ?? "").trim();
      if (rawUrl.isEmpty) {
        AppSnackBar.showErrorSnackBar(message: failureLabel);
        return;
      }

      // Add a scheme if missing, so Uri.parse produces a valid http(s) URI
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(rawUrl)) {
        rawUrl = 'https://$rawUrl';
      }

      uri = Uri.tryParse(rawUrl);
    }

    if (uri == null) {
      AppLogger.e("Invalid url: $url");
      AppSnackBar.showErrorSnackBar(message: failureLabel);
      return;
    }

    final bool canLaunch = await canLaunchUrl(uri);

    if (canLaunch || isExternal) {
      final launched = await launchUrl(
        uri,
        mode: isExternal
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
      if (!launched) {
        AppSnackBar.showSuccessSnackBar(message: failureLabel);
      }
    } else {
      AppSnackBar.showSuccessSnackBar(message: failureLabel);
    }
  } catch (e) {
    AppLogger.e("Url is $url");
    AppLogger.e('openUrl error: $e');
    AppSnackBar.showErrorSnackBar(message: failureLabel);
  }
}

Image staticImage({
  required String url,
  double? w,
  double? h,
  Color? color,
  BoxFit fit = BoxFit.cover,
}) => Image.asset(url, width: w, height: h, fit: fit, color: color);

SizedBox spacerH(double h) => h.verticalSpace;

SizedBox spacerW(double w) => w.horizontalSpace;

String formatTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inDays > 0) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes > 0) {
    return '${diff.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

void removeFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
}

String? normalizedUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
  return hasScheme ? trimmed : 'https://$trimmed';
}
