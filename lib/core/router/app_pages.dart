import 'package:dating_app/presentation/auth/screens/age_screen.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen1.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen2.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen3.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen4.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen5.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen7.dart';
import 'package:dating_app/presentation/auth/screens/login_screen.dart';
import 'package:dating_app/presentation/auth/screens/otp_screen.dart';
import 'package:dating_app/presentation/auth/screens/splash_screen.dart';
import 'package:dating_app/presentation/auth/screens/status_screen.dart';
import 'package:dating_app/presentation/home/screens/archived_chats_screen.dart';
import 'package:dating_app/presentation/home/screens/dashboard_screen.dart';
import 'package:dating_app/presentation/home/screens/premium_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../presentation/common/force_update_maintenance/presentation/pages/force_update_screen.dart';
import '../../presentation/home/screens/location_sharing_screen.dart';
import '../../presentation/internet/view/screens/internet_screen.dart';
import '../../presentation/notifications/view/pages/notification_screen.dart';
import 'app_router.dart';

GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      // `extra: true` means "a session was just created, skip the version and
      // maintenance checks".
      pageBuilder: (c, s) =>
          _rtl(SplashScreen(skipStartupChecks: s.extra == true)),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (c, s) => _rtl(const LoginScreen()),
    ),
    GoRoute(
      path: AppRoutes.signInOtp,
      // `extra` is the full phone number.
      pageBuilder: (c, s) =>
          _rtl(OtpScreen(phoneNumber: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: AppRoutes.forceUpdate,
      pageBuilder: (c, s) => _rtl(const ForceUpdateScreen()),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      pageBuilder: (c, s) => _rtl(const DashboardScreen()),
    ),
    GoRoute(
      path: AppRoutes.archivedChats,
      pageBuilder: (c, s) => _rtl(const ArchivedChatsScreen()),
    ),
    GoRoute(
      path: AppRoutes.buyPremium,
      pageBuilder: (c, s) => _rtl(const PremiumScreen()),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (c, s) => _rtl(const NotificationsScreen()),
    ),
    GoRoute(
      path: AppRoutes.internet,
      name: 'internet',
      builder: (context, state) => const InternetScreen(),
    ),
    GoRoute(
      path: AppRoutes.locationSharing,
      pageBuilder: (c, s) => _rtl(const LocationSharingScreen()),
    ),

    // ── Onboarding ──────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.age,
      pageBuilder: (c, s) => _rtl(const AgeScreen()),
    ),
    GoRoute(
      path: AppRoutes.basics,
      // `extra` is the display name typed on the age screen.
      pageBuilder: (c, s) =>
          _rtl(BasicsScreen(displayName: s.extra as String? ?? '')),
    ),
    GoRoute(
      path: AppRoutes.intent,
      pageBuilder: (c, s) => _rtl(const BasicsScreen2()),
    ),
    GoRoute(
      path: AppRoutes.status,
      pageBuilder: (c, s) => _rtl(const StatusScreen()),
    ),
    GoRoute(
      path: AppRoutes.preferences,
      pageBuilder: (c, s) => _rtl(const BasicsScreen3()),
    ),
    GoRoute(
      path: AppRoutes.photos,
      pageBuilder: (c, s) => _rtl(const BasicsScreen4()),
    ),
    GoRoute(
      path: AppRoutes.location,
      pageBuilder: (c, s) => _rtl(const BasicsScreen5()),
    ),
    GoRoute(
      path: AppRoutes.agreement,
      pageBuilder: (c, s) => _rtl(const BasicsScreen7()),
    ),
  ],
);

/// Slides in from the right, out to the right.
CustomTransitionPage _rtl(Widget child) => CustomTransitionPage(
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (_, anim, _, child) {
    final curved = CurvedAnimation(
      parent: anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: anim, child: child),
    );
  },
);