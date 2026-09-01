import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/static_assets/app_icons.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_loader.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import 'package:pub_semver/pub_semver.dart';
import '../../../providers/profile_provider.dart';
import '../../common/force_update_maintenance/presentation/pages/maintenance_page.dart';
import '../../home/screens/home_screen.dart';
import 'age_screen.dart';
import 'basics_screen1.dart';
import 'basics_screen2.dart';
import 'basics_screen3.dart';
import 'basics_screen4.dart';
import 'basics_screen5.dart';
import 'basics_screen7.dart';
import 'login_screen.dart';
import 'status_screen.dart';

/// Entry point once a Supabase session exists: loads the domain user
/// (`GET /users/me`, which also provisions it on first call) and routes to home
/// or back into the funnel at the exact step the backend says is outstanding.
class AuthedBootstrap extends ConsumerWidget {
  const AuthedBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return me.when(
      loading: () => const _SplashPage(),
      error: (err, _) => _ErrorRetry(
        message: err.toString(),
        onRetry: () => ref.invalidate(meProvider),
      ),
      data: (user) => user.onboarding.isComplete
          ? const HomeScreen()
          : _resumeAt(user.onboarding.nextStep),
    );
  }

  /// Maps the backend's outstanding step to the screen that satisfies it, so a
  /// refresh mid-funnel picks up where the user left off instead of restarting
  /// from the age gate.
  ///
  /// Two screens each save a pair of steps (intent+personality,
  /// preferences+hard-no's), so both of those steps route to the same screen.
  Widget _resumeAt(String? nextStep) {
    switch (nextStep) {
      case OnboardingSteps.ageVerification:
        return const AgeScreen();
      case OnboardingSteps.basics:
        return const BasicsScreen();
      case OnboardingSteps.intent:
      case OnboardingSteps.personality:
        return const BasicsScreen2();
      case OnboardingSteps.status:
        return const StatusScreen();
      case OnboardingSteps.preferences:
      case OnboardingSteps.hardNos:
        return const BasicsScreen3();
      case OnboardingSteps.photo:
        return const BasicsScreen4();
      case OnboardingSteps.location:
        return const BasicsScreen5();
      case OnboardingSteps.agreement:
        return const BasicsScreen7();
      default:
        // No step named (or an unknown one from a newer backend): start over
        // rather than guess. Completed steps are skipped by the funnel anyway.
        return const AgeScreen();
    }
  }
}

class _SplashPage extends StatefulWidget {
  const _SplashPage();

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage> {
  String _cachedAppVersion = '0.0.0';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _initialize();
    });
  }

  // Future<void> _initialize() async {
  //   try {
  //     await Future.delayed(const Duration(seconds: 2));
  //     if (!mounted) return;
  //
  //     // ── Fetch Remote Config ONCE and reuse it for both checks below.
  //     // Calling fetchAndActivate() twice back-to-back (once for version,
  //     // once for maintenance) is what triggers the
  //     // [firebase_remote_config/throttled] error — Firebase enforces a
  //     // fetch quota, and hammering it twice per splash load burns through
  //     // it fast (especially during dev/hot-restart testing).
  //     final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  //     await _fetchRemoteConfigSafely(remoteConfig);
  //     if (!mounted) return;
  //
  //     final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  //     _cachedAppVersion = packageInfo.version;
  //     AppLogger.d(
  //       "Local App Version: $_cachedAppVersion "
  //           "(package: ${packageInfo.packageName}, build: ${packageInfo.buildNumber})",
  //     );
  //     if (!mounted) return;
  //
  //     // ── Step 1: Force-update check ─────────────────────────────────────
  //     final bool needsUpdate = _checkAppVersion(remoteConfig);
  //     if (!mounted) return;
  //
  //     if (needsUpdate) {
  //       context.go(AppRoutes.forceUpdate);
  //       return;
  //     }
  //
  //     // ── Step 2: Maintenance check ────────────────────────────────────────
  //     final bool isUnderMaintenance = _checkMaintenanceMode(remoteConfig);
  //     if (!mounted) return;
  //
  //     if (isUnderMaintenance) {
  //       return;
  //     }
  //
  //     // ── Step 3: Auth routing ─────────────────────────────────────────────
  //     String? token;
  //     try {
  //       final data = await HiveHelper.getData(key: HiveKeys.token);
  //       token = data?.toString();
  //     } catch (e, st) {
  //       AppLogger.e("Failed to read auth token from Hive: $e");
  //       AppLogger.e("Stacktrace: $st");
  //       token = null; // fall back to onboarding if local storage read fails
  //     }
  //
  //     if (!mounted) return;
  //
  //     if (token != null && token.isNotEmpty) {
  //       context.go(AppRoutes.dashboard);
  //     } else {
  //       context.go(AppRoutes.onboard);
  //     }
  //   } catch (e, st) {
  //     // Outer safety net — never leave the user stuck on the splash screen.
  //     AppLogger.e("!!! UNHANDLED ERROR IN SPLASH INITIALIZE !!!");
  //     AppLogger.e("Exception: $e");
  //     AppLogger.e("Stacktrace: $st");
  //   }
  // }

  /// Fetches & activates Remote Config exactly once per splash run.
  ///
  /// - Uses a sane [minimumFetchInterval] instead of [Duration.zero], so
  ///   repeated app launches within a short window reuse the cached config
  ///   instead of hitting the network (and the throttle quota) every time.
  ///   Short interval for debug builds, longer for release.
  /// - If the fetch itself is throttled or fails for any other reason (no
  ///   network, timeout, etc.), we swallow the error and fall back to
  ///   whatever config is already cached/activated from a previous run —
  ///   `remoteConfig.getString(...)` still works fine on stale data, it
  ///   just won't reflect the very latest values.
  Future<void> _fetchRemoteConfigSafely(
      FirebaseRemoteConfig remoteConfig,
      ) async {
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 1)
              : const Duration(hours: 1),
        ),
      );

      AppLogger.d("Fetching and activating Remote Config from Firebase...");
      final bool fetchStatus = await remoteConfig.fetchAndActivate();
      AppLogger.d(
        "Firebase fetch & activate status: ${fetchStatus ? 'NEW DATA ACTIVATED / CACHED DATA FRESH' : 'NO NEW DATA TO ACTIVATE'}",
      );
    } catch (e, st) {
      // Includes [firebase_remote_config/throttled] and any other fetch
      // failure. We deliberately do NOT rethrow — the splash flow should
      // proceed using whatever is already cached/activated (or the SDK's
      // in-code defaults) rather than get stuck.
      AppLogger.e(
        "Remote Config fetch failed (using cached/default values): $e",
      );
      AppLogger.e("Stacktrace: $st");
    }
  }

  /// Checks if the current app version is lower than the minimum required
  /// version. Reads from the already-activated [remoteConfig] instance —
  /// does NOT fetch again.
  bool _checkAppVersion(FirebaseRemoteConfig remoteConfig) {
    try {
      AppLogger.d("=== STARTING APP VERSION CHECK ===");
      AppLogger.d(
        " -> Detected Platform: Android=${defaultTargetPlatform == TargetPlatform.android}, iOS=${defaultTargetPlatform == TargetPlatform.iOS}",
      );

      final String minimumRequiredVersionStr = remoteConfig.getString(
        'force_update_minimum_version',
      );
      AppLogger.d(
        "Firebase Remote Config value for 'force_update_minimum_version': '$minimumRequiredVersionStr'",
      );

      if (minimumRequiredVersionStr.isEmpty) {
        AppLogger.d(
          "Result: Firebase returned an empty string. No update is required. Returning false.",
        );
        return false;
      }

      AppLogger.d(
        "Parsing version strings into Semantic Versioning objects...",
      );
      final Version currentVersion = Version.parse(_cachedAppVersion);
      final Version minimumRequiredVersion = Version.parse(
        minimumRequiredVersionStr,
      );

      AppLogger.d("Parsed Version Details:");
      AppLogger.d(" -> Parsed Current Version object: $currentVersion");
      AppLogger.d(
        " -> Parsed Minimum Required Version object: $minimumRequiredVersion",
      );

      final bool isCurrentLessThanRequired =
          currentVersion < minimumRequiredVersion;
      AppLogger.d(
        "Is current version ($currentVersion) strictly less than required version ($minimumRequiredVersion)? Result: $isCurrentLessThanRequired",
      );
      AppLogger.d(
        "=== ENDING APP VERSION CHECK - Final Result: $isCurrentLessThanRequired ===",
      );
      return isCurrentLessThanRequired;
    } catch (e, stacktrace) {
      AppLogger.e("!!! CRITICAL ERROR DURING APP VERSION CHECK !!!");
      AppLogger.e("Exception caught: $e");
      AppLogger.e("Stacktrace: $stacktrace");
      AppLogger.e(
        "Returning fallback value: false (User will bypass update screen to prevent locking them out)",
      );
      return false;
    }
  }

  /// Checks if the app is currently in Maintenance Mode. Reads from the
  /// already-activated [remoteConfig] instance — does NOT fetch again.
  bool _checkMaintenanceMode(FirebaseRemoteConfig remoteConfig) {
    try {
      AppLogger.d("=== STARTING MAINTENANCE CHECK ===");

      final String rawJsonConfig = remoteConfig.getString('maintenance_mode');
      AppLogger.d("Raw Firebase JSON Config received: $rawJsonConfig");

      bool isMaintenanceMode = false;
      String customTitle = "We're upgrading our systems";
      String customMessage =
          "Our platform is currently undergoing scheduled maintenance. We'll be back online shortly!";

      if (rawJsonConfig.isNotEmpty) {
        final Map<String, dynamic> parsedConfig = jsonDecode(rawJsonConfig);
        isMaintenanceMode = parsedConfig['is_maintenance_mode'] ?? false;
        customTitle = parsedConfig['maintenance_title'] ?? customTitle;
        customMessage = parsedConfig['maintenance_message'] ?? customMessage;
      }

      AppLogger.d(
        "Parsed Maintenance Status -> is_maintenance_mode: $isMaintenanceMode",
      );

      if (isMaintenanceMode && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MaintenancePage(
              title: customTitle,
              message: customMessage,
              onRefresh: () async {
                AppLoader.show();
                // Manual "retry" from the maintenance page — a deliberate
                // user action, so a real fetch here is fine.
                await _fetchRemoteConfigSafely(remoteConfig);
                final bool stillInMaintenance = _checkMaintenanceMode(
                  remoteConfig,
                );
                AppLoader.hide();

                if (!stillInMaintenance) {
                  // if (mounted) context.go(AppRoutes.splash);
                } else {
                  AppSnackBar.showWarningSnackBar(
                    message: "Current App is in Maintenance Mode!",
                  );
                }
              },
            ),
          ),
              (route) => false,
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e("Failed to check maintenance config: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: kIsWeb
            ? const _WebSplashSkeleton()
            : Center(
          child: staticImage(
            url: AppIcons.roundedLauncherIconNoBg,
            w: 200,
          ),
        ),
      ),
    );
  }
}

class _WebSplashSkeleton extends StatefulWidget {
  const _WebSplashSkeleton();

  @override
  State<_WebSplashSkeleton> createState() => _WebSplashSkeletonState();
}

class _WebSplashSkeletonState extends State<_WebSplashSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _messageTimer;

  final List<String> _loadingMessages = [
    "Preparing Your Experience...",
    "Almost Ready...",
  ];

  int _currentIndex = 0;
  String _currentMessage = "Preparing Your Experience...";

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentIndex < _loadingMessages.length - 1) {
        setState(() {
          _currentIndex++;
          _currentMessage = _loadingMessages[_currentIndex];
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isMobile = width < 650;
        final bool isTablet = width >= 650 && width < 1024;

        return Stack(
          children: [
            Positioned.fill(
              child: isMobile
                  ? _buildMobileSkeleton(width)
                  : isTablet
                  ? _buildTabletSkeleton(width)
                  : _buildDesktopSkeleton(width),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _currentMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 📱 MOBILE LAYOUT SKELETON
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileSkeleton(double maxWidth) {
    // Reserve horizontal padding, everything else scales off what's left.
    final double contentWidth = maxWidth - 32; // 16px padding each side

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmerBox(width: contentWidth * 0.28, height: 28, radius: 6),
              _shimmerBox(width: 36, height: 36, radius: 18),
            ],
          ),
          const SizedBox(height: 40),
          _shimmerBox(
            width: (contentWidth * 0.75).clamp(0, contentWidth),
            height: 32,
            radius: 6,
          ),
          const SizedBox(height: 8),
          _shimmerBox(
            width: (contentWidth * 0.5).clamp(0, contentWidth),
            height: 32,
            radius: 6,
          ),
          const SizedBox(height: 16),
          _shimmerBox(width: contentWidth, height: 14, radius: 4),
          const SizedBox(height: 6),
          _shimmerBox(
            width: (contentWidth * 0.7).clamp(0, contentWidth),
            height: 14,
            radius: 4,
          ),
          const SizedBox(height: 32),
          _shimmerBox(width: contentWidth, height: 220, radius: 12),
          const SizedBox(height: 32),
          ...List.generate(
            2,
                (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPremiumCardMobile(contentWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCardMobile(double contentWidth) {
    return Container(
      width: contentWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _shimmerBox(width: 48, height: 48, radius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 120, height: 16, radius: 4),
                const SizedBox(height: 8),
                _shimmerBox(width: double.infinity, height: 10, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ⏸️ TABLET LAYOUT SKELETON
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTabletSkeleton(double maxWidth) {
    final double contentWidth = maxWidth - 64; // 32px padding each side

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmerBox(width: 130, height: 32, radius: 6),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _shimmerBox(width: 60, height: 14, radius: 4),
                    const SizedBox(width: 20),
                    _shimmerBox(width: 60, height: 14, radius: 4),
                    const SizedBox(width: 20),
                    _shimmerBox(width: 100, height: 36, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          Center(
            child: Column(
              children: [
                _shimmerBox(
                  width: (contentWidth * 0.75).clamp(0, contentWidth),
                  height: 38,
                  radius: 8,
                ),
                const SizedBox(height: 12),
                _shimmerBox(
                  width: (contentWidth * 0.5).clamp(0, contentWidth),
                  height: 38,
                  radius: 8,
                ),
                const SizedBox(height: 20),
                _shimmerBox(
                  width: (contentWidth * 0.8).clamp(0, contentWidth),
                  height: 14,
                  radius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _shimmerBox(
                  width: double.infinity,
                  height: 340,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(
                    3,
                        (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _shimmerBox(
                        width: double.infinity,
                        height: 102,
                        radius: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 💻 DESKTOP & 4K LAYOUT SKELETON
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopSkeleton(double maxWidth) {
    final double cappedWidth = maxWidth > 1320 ? 1320 : maxWidth;
    final double contentWidth = cappedWidth - 80; // 40px padding each side

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: cappedWidth),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _shimmerBox(width: 140, height: 36, radius: 8),
                        const SizedBox(width: 48),
                        _shimmerBox(width: 70, height: 14, radius: 4),
                        const SizedBox(width: 32),
                        _shimmerBox(width: 70, height: 14, radius: 4),
                        const SizedBox(width: 32),
                        _shimmerBox(width: 70, height: 14, radius: 4),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _shimmerBox(width: 80, height: 14, radius: 4),
                        const SizedBox(width: 32),
                        _shimmerBox(width: 120, height: 42, radius: 21),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(width: 120, height: 24, radius: 12),
                        const SizedBox(height: 24),
                        _shimmerBox(
                          width: double.infinity,
                          height: 48,
                          radius: 8,
                        ),
                        const SizedBox(height: 12),
                        _shimmerBox(
                          width: (contentWidth * 0.35).clamp(0, contentWidth),
                          height: 48,
                          radius: 8,
                        ),
                        const SizedBox(height: 24),
                        _shimmerBox(
                          width: double.infinity,
                          height: 16,
                          radius: 4,
                        ),
                        const SizedBox(height: 8),
                        _shimmerBox(
                          width: (contentWidth * 0.3).clamp(0, contentWidth),
                          height: 16,
                          radius: 4,
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            _shimmerBox(width: 150, height: 48, radius: 8),
                            const SizedBox(width: 16),
                            _shimmerBox(width: 130, height: 48, radius: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    flex: 6,
                    child: _shimmerBox(
                      width: double.infinity,
                      height: 420,
                      radius: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 96),
              Row(
                children: List.generate(
                  3,
                      (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shimmerBox(width: 44, height: 44, radius: 10),
                          const SizedBox(height: 20),
                          _shimmerBox(width: 140, height: 18, radius: 4),
                          const SizedBox(height: 12),
                          _shimmerBox(
                            width: double.infinity,
                            height: 12,
                            radius: 4,
                          ),
                          const SizedBox(height: 6),
                          _shimmerBox(
                            width: double.infinity,
                            height: 12,
                            radius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ✨ CORE SHIMMER ENGINE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 4,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: const [0.3, 0.5, 0.7],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: Container(
            width: width == double.infinity ? double.infinity : width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.textGrey),
              const SizedBox(height: 16),
              Text(
                "Couldn't reach cozune",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
