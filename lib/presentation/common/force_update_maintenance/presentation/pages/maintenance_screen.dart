import 'package:flutter/material.dart';

import '../../../../../core/constants/app_string.dart';
import '../../../../../core/extensions/global_back_extension.dart';
import '../../../widgets/system_state.dart';

/// Shown while remote config says the backend is down for maintenance. The
/// title and message can be set from remote config; these defaults cover the
/// case where they are not.
class MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;

  /// Re-reads remote config. Shows its own loader.
  final VoidCallback onRefresh;

  const MaintenanceScreen({
    super.key,
    this.title = AppString.maintenanceTitleDefault,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SystemStateLayout(
      icon: Icons.construction_rounded,
      // Remote config titles were written with a hard line break for the old
      // centred layout; the left-aligned headline wraps on its own.
      title: title.replaceAll('\n', ' '),
      message: message,
      actionLabel: 'Check again',
      onAction: onRefresh,
    ).withGlobalBackHandler(context);
  }
}
