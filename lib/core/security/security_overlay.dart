import 'dart:async';

import 'package:dating_app/core/security/security_breach_page.dart';
import 'package:dating_app/core/security/security_risk.dart';
import 'package:dating_app/core/security/security_service.dart';
import 'package:flutter/material.dart';

/// Re-checks device security while the app is running (on resume and on live
/// Talsec threats) and shows the breach page over the app if needed.
class SecurityOverlay extends StatefulWidget {
  final Widget child;

  const SecurityOverlay({super.key, required this.child});

  @override
  State<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends State<SecurityOverlay>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _liveThreatSub;

  final ValueNotifier<List<SecurityRisk>> _breachRisks =
      ValueNotifier<List<SecurityRisk>>(const []);

  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveThreatSub = SecurityService.liveThreatStream.listen(
      (_) => _runLiveCheck(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveThreatSub?.cancel();
    _breachRisks.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runLiveCheck();
    }
  }

  Future<void> _runLiveCheck({bool fresh = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await SecurityService.checkNow(fresh: fresh);
      if (!mounted) return;

      // Soft risks are warnings only; a screenshot is an event, not a breach.
      _breachRisks.value = result.risks
          .where(
            (r) =>
                SecurityService.isHardRisk(r) &&
                r != SecurityRisk.screenshotTaken,
          )
          .toList();
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<List<SecurityRisk>>(
          valueListenable: _breachRisks,
          builder: (context, risks, _) {
            if (risks.isEmpty) return const SizedBox.shrink();
            return Positioned.fill(
              child: PopScope(
                canPop: false,
                child: SecurityBreachPage(
                  embedded: true,
                  risks: risks,
                  onRecheck: () => _runLiveCheck(fresh: true),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
