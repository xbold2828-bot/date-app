import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/is_user_have_premium_provider.dart';
import '../ad_helper.dart';
import 'app_open_ad_state.dart';

const Duration kMinGapBetweenAppOpenAds = Duration(minutes: 15);
const Duration kAppOpenAdMaxCacheAge = Duration(hours: 4);

/// After a login, no app-open ad is shown for this long. Premium status
/// arrives from the server a few seconds after login; this window makes sure
/// it has long since been confirmed, so a premium user never sees an ad.
const Duration kPostLoginAdDelay = Duration(minutes: 15);

const String _kLastShownPrefsKey = 'app_open_ad_last_shown_at';
const String _kSessionStartPrefsKey = 'app_open_ad_session_started_at';

class AppOpenAdController extends Notifier<AppOpenAdState>
    with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  DateTime? _adLoadedAt;
  DateTime? _lastShownAt;

  /// When the current login session began. Null = no login recorded yet,
  /// in which case NO ad is shown.
  DateTime? _sessionStartedAt;

  bool _disposed = false;

  /// Completes once the saved timestamps have been read from disk.
  Future<void> _ready = Future.value();

  @override
  AppOpenAdState build() {
    _disposed = false;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      _appOpenAd?.dispose();
      _appOpenAd = null;
    });

    // Reads prefs only; it does not touch `state`, so it is safe to start
    // here. Until it finishes, _sessionStartedAt is null and nothing shows.
    _ready = _restoreTimes();

    // Don't touch `state` synchronously inside build() — the provider
    // isn't initialized until build() returns. Defer to a microtask.
    // (Loading an ad is fine during the grace period; only SHOWING is gated.)
    Future.microtask(_loadAd);

    return const AppOpenAdState();
  }

  // ── Login-session tracking ────────────────────────────────────────────────

  /// Call when the user has just logged in (fresh sign-in, not a restored
  /// session). Starts the [kPostLoginAdDelay] window.
  Future<void> onLoggedIn() async {
    await _ready;
    _sessionStartedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kSessionStartPrefsKey,
      _sessionStartedAt!.millisecondsSinceEpoch,
    );
  }

  /// Call when the app starts with an already-signed-in user. Only starts the
  /// window if none is saved yet (e.g. an update from a version that did not
  /// track it), so a restored session never resets an older, valid window.
  Future<void> ensureSessionStarted() async {
    await _ready;
    if (_sessionStartedAt != null) return;
    await onLoggedIn();
  }

  /// Call on logout so the next login starts a fresh window and no ad is
  /// shown to a signed-out user.
  Future<void> onLoggedOut() async {
    await _ready;
    _sessionStartedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionStartPrefsKey);
  }

  Future<void> _restoreTimes() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;

    final shown = prefs.getInt(_kLastShownPrefsKey);
    if (shown != null) {
      _lastShownAt = DateTime.fromMillisecondsSinceEpoch(shown);
    }

    final started = prefs.getInt(_kSessionStartPrefsKey);
    if (started != null) {
      _sessionStartedAt = DateTime.fromMillisecondsSinceEpoch(started);
    }
  }

  Future<void> _persistLastShownTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastShownPrefsKey, time.millisecondsSinceEpoch);
  }

  // ── Eligibility ───────────────────────────────────────────────────────────

  bool get _isAdFresh {
    if (_adLoadedAt == null) return false;
    return DateTime.now().difference(_adLoadedAt!) < kAppOpenAdMaxCacheAge;
  }

  bool get _isAdAvailable => _appOpenAd != null && _isAdFresh;

  bool get _cooldownElapsed {
    if (_lastShownAt == null) return true;
    return DateTime.now().difference(_lastShownAt!) >=
        kMinGapBetweenAppOpenAds;
  }

  /// True only once the user has been logged in for [kPostLoginAdDelay].
  /// No recorded login (or prefs not read yet) means false.
  bool get _loginDelayElapsed {
    final started = _sessionStartedAt;
    if (started == null) return false;
    return DateTime.now().difference(started) >= kPostLoginAdDelay;
  }

  void _loadAd() {
    if (_disposed) return;
    if (state.isLoadingAd || _isAdAvailable) return;

    state = state.copyWith(isLoadingAd: true);

    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _appOpenAd = ad;
          _adLoadedAt = DateTime.now();
          state = state.copyWith(isLoadingAd: false);
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) print('App open ad failed: $error');
          if (_disposed) return;
          state = state.copyWith(isLoadingAd: false);
        },
      ),
    );
  }

  void showAdIfEligible() {
    if (_disposed) return;

    // Premium users never see this ad…
    if (ref.read(isUserHavePremiumProvider)) return;

    // …and nobody sees it until 15 minutes after login, by which time the
    // premium flag has certainly been confirmed by the server. Without this,
    // a premium user could get an ad in the few seconds before the flag lands.
    if (!_loginDelayElapsed) return;

    if (state.isShowingAd || !_cooldownElapsed) return;

    if (!_isAdAvailable) {
      _loadAd();
      return;
    }

    final ad = _appOpenAd!;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (!_disposed) state = state.copyWith(isShowingAd: true);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false);
          _loadAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false);
          _loadAd();
        }
      },
    );

    _lastShownAt = DateTime.now();
    _persistLastShownTime(_lastShownAt!);
    ad.show();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) showAdIfEligible();
  }
}

final appOpenAdControllerProvider =
NotifierProvider<AppOpenAdController, AppOpenAdState>(
  AppOpenAdController.new,
);