import 'package:dating_app/core/security/security_risk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../presentation/common/widgets/system_state.dart';
import '../extensions/global_back_extension.dart';
import '../theme/app_theme.dart';

/// Metadata used to render a [SecurityRisk] in a human-readable way.
class _RiskInfo {
  final String title;
  final String description;
  final IconData icon;

  const _RiskInfo(this.title, this.description, this.icon);
}

const Map<SecurityRisk, _RiskInfo> _riskInfo = {
  SecurityRisk.jailbrokenOrRooted: _RiskInfo(
    'Rooted or jailbroken',
    'This phone has root access, which lets other apps read what cozune '
        'keeps private.',
    Icons.phonelink_lock_outlined,
  ),
  SecurityRisk.bootloaderUnlocked: _RiskInfo(
    'Bootloader unlocked',
    "The phone's bootloader is unlocked, so its system can be changed in "
        'ways that get around app security.',
    Icons.lock_open_outlined,
  ),
  SecurityRisk.debuggerAttached: _RiskInfo(
    'Debugger attached',
    'A debugging tool is connected to cozune and could read or change it '
        'while it runs.',
    Icons.bug_report_outlined,
  ),
  SecurityRisk.devModeEnabled: _RiskInfo(
    'Developer options are on',
    'Turn off Developer options and USB debugging in Settings, then check '
        'again.',
    Icons.usb_off_outlined,
  ),
  SecurityRisk.hookDetected: _RiskInfo(
    'Hooking tool found',
    'A tool like Frida or Xposed is running and can change how cozune '
        'behaves.',
    Icons.link_off_outlined,
  ),
  SecurityRisk.appTampered: _RiskInfo(
    'This copy of cozune was modified',
    'Delete it and install cozune again from the store.',
    Icons.gpp_bad_outlined,
  ),
  SecurityRisk.appIntegrityFailed: _RiskInfo(
    "Signature doesn't match",
    "This copy isn't the one we published. Install cozune from the store.",
    Icons.verified_outlined,
  ),
  SecurityRisk.notRealDevice: _RiskInfo(
    'Running on an emulator',
    'cozune only runs on a real phone.',
    Icons.devices_other_outlined,
  ),
  SecurityRisk.multiInstanceApp: _RiskInfo(
    'Cloned copy of the app',
    'A second, cloned copy of cozune is installed. Remove it and keep the '
        'original.',
    Icons.content_copy_outlined,
  ),
  SecurityRisk.screenCaptured: _RiskInfo(
    'Screen is being recorded',
    'Stop the recording or screen mirroring, then check again.',
    Icons.screen_share_outlined,
  ),
  SecurityRisk.passcodeNotSet: _RiskInfo(
    'No screen lock',
    'Set a PIN, pattern or password for this phone in Settings.',
    Icons.pin_outlined,
  ),
  SecurityRisk.obfuscationIssues: _RiskInfo(
    'Build check failed',
    'This build of cozune failed an internal integrity check.',
    Icons.report_gmailerrorred_outlined,
  ),
  SecurityRisk.mockLocation: _RiskInfo(
    'Fake location app on',
    'Turn off the mock location app — cozune needs your real area.',
    Icons.location_off_outlined,
  ),
  SecurityRisk.externalStorage: _RiskInfo(
    'Installed on an SD card',
    'Move cozune to internal storage, or reinstall it there.',
    Icons.sd_storage_outlined,
  ),
};

class SecurityBreachPage extends StatefulWidget {
  final List<SecurityRisk> risks;

  /// Called when the user taps "Check again" — should re-run
  /// [SecurityService.evaluate] and rebuild accordingly.
  final VoidCallback? onRecheck;

  const SecurityBreachPage({super.key, required this.risks, this.onRecheck});

  @override
  State<SecurityBreachPage> createState() => _SecurityBreachPageState();
}

class _SecurityBreachPageState extends State<SecurityBreachPage> {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Builder(builder: _buildBody),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final known = [
      for (final risk in widget.risks)
        if (_riskInfo[risk] != null) _riskInfo[risk]!,
    ];

    return SystemStateLayout(
      icon: Icons.gpp_maybe_outlined,
      danger: true,
      title: "This phone isn't secure right now",
      message: known.length == 1
          ? 'cozune stays closed until this is fixed. Fix it, then check '
                'again.'
          : 'cozune stays closed until these ${known.length} things are '
                'fixed. Fix them, then check again.',
      actionLabel: 'Check again',
      onAction: widget.onRecheck ?? () {},
      children: [
        for (var i = 0; i < known.length; i++)
          SystemStateRow(
            icon: known[i].icon,
            title: known[i].title,
            description: known[i].description,
          ),
      ],
    ).withGlobalBackHandler(context);
  }
}
