import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/common/widgets/step_header.dart';
import '../constants/app_constants.dart';
import '../constants/app_string.dart';
import '../constants/app_text_styles.dart';
import '../theme/app_colors.dart';
import 'app_lock_provider.dart';

/// Wraps the whole app: watches the lifecycle and covers everything with
/// [LockScreen] while locked. The app underneath stays mounted but is
/// offstage (not painted, not tappable, hidden from screen readers).
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    // `inactive` is deliberately ignored: the biometric prompt, the
    // notification shade and permission dialogs all cause it.
    if (state == AppLifecycleState.paused) {
      lock.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      lock.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider.select((s) => s.locked));
    // Same tree shape locked or not, so the app underneath is never remounted.
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: locked, child: widget.child),
        if (locked) const LockScreen(),
      ],
    );
  }
}

/// Full-screen lock: flat background, a solid medallion with pulsing rings,
/// and a solid unlock button. No gradients anywhere.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prompt automatically as soon as the lock screen is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();

    await ref
        .read(appLockProvider.notifier)
        .unlock(AppString.appLockUnlockReason);

    if (!mounted) return;
    setState(() => _busy = false);

    // Still locked after the prompt: cancelled or not recognised.
    if (ref.read(appLockProvider).locked) {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  Animation<double> _stagger(double begin, double end) => CurvedAnimation(
    parent: _enter,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  Widget _reveal(Animation<double> a, Widget child, {double dy = 18}) {
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, (1 - a.value) * dy),
          child: c,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;

    // Back must not reach the app hidden underneath; just leave the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  _reveal(_stagger(0.0, 0.5), const Wordmark()),
                  const Spacer(flex: 3),
                  _reveal(
                    _stagger(0.1, 0.7),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) {
                        final t = _shake.value;
                        final dx = math.sin(t * math.pi * 5) * 12 * (1 - t);
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: _Emblem(pulse: _pulse, busy: _busy, dark: dark),
                    ),
                    dy: 28,
                  ),
                  const SizedBox(height: 44),
                  _reveal(
                    _stagger(0.25, 0.85),
                    Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            AppString.appLockLockedTitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.title.copyWith(
                              fontSize: 28,
                              letterSpacing: -0.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppString.appLockLockedBody,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  _reveal(
                    _stagger(0.4, 1.0),
                    Column(
                      children: [
                        _UnlockButton(busy: _busy, onTap: _unlock),
                        const SizedBox(height: 18),
                        const _SecuredNote(),
                      ],
                    ),
                    dy: 24,
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppConstants.appName.toLowerCase(),
          style: AppTextStyles.title.copyWith(
            fontSize: 19,
            letterSpacing: 1.6,
            color: AppColors.textDark.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// Solid medallion with a primary rim, a soft glow and three expanding rings.
/// While the system prompt is open the icon swaps to a fingerprint.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.pulse, required this.busy, required this.dark});

  final Animation<double> pulse;
  final bool busy;
  final bool dark;

  static const double _core = 112;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding rings, staggered by a third of the cycle.
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) {
                final t = (pulse.value + i / 3) % 1.0;
                final eased = Curves.easeOut.transform(t);
                final size = _core + eased * 150;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: (1 - t) * (dark ? 0.40 : 0.28)),
                      width: 1.2,
                    ),
                  ),
                );
              },
            ),
          // Solid medallion with a primary rim and a soft shadow.
          Container(
            width: _core,
            height: _core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? AppColors.card : AppColors.primaryTint,
              border: Border.all(color: AppColors.primary, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color:
                  AppColors.primary.withValues(alpha: dark ? 0.35 : 0.25),
                  blurRadius: 40,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: a,
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: Icon(
                  busy ? Icons.fingerprint_rounded : Icons.lock_rounded,
                  key: ValueKey(busy),
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width solid pill with a soft shadow and a press scale.
class _UnlockButton extends StatefulWidget {
  const _UnlockButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  State<_UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends State<_UnlockButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: AppString.appLockUnlockButton,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.7,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 58,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.busy
                      ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.onAccent,
                    ),
                  )
                      : Row(
                    key: const ValueKey('idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 24,
                        color: AppColors.onAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppString.appLockUnlockButton,
                        style: TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecuredNote extends StatelessWidget {
  const _SecuredNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_rounded,
          size: 15,
          color: AppColors.textGrey.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppString.appLockSecuredNote,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: AppColors.textGrey,
            ),
          ),
        ),
      ],
    );
  }
}