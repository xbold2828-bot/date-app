import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/explore_provider.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../../home/screens/premium_screen.dart';
import '../../home/widgets/discovery_filter_sheet.dart';
import '../widgets/explore_controls.dart';
import '../widgets/explore_map.dart';
import '../widgets/explore_profile_preview.dart';
import '../widgets/explore_states.dart';

/// Explore — the people the Radar tab would show you, on the ground they are
/// actually on.
///
/// The screen owns no discovery logic of its own. [exploreProvider] asks the
/// same endpoint family the Radar grid asks, parameterised by the same
/// [discoveryFilterProvider], so eligibility, radius, preferences, visibility
/// and blocking are decided in exactly one place — the backend — and this is a
/// second way of *looking* at that answer rather than a second answer.
///
/// Everything is stacked over a map that never goes away. Loading, empty,
/// paywalled, offline, permission-denied: the city stays on screen and the
/// explanation floats over it.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _map = ExploreMapController();

  @override
  void initState() {
    super.initState();
    // A selection is about a marker on a map, not a durable choice. Coming
    // back to the tab with a card already open over a map you have not looked
    // at yet is disorienting, so the previous one is cleared on arrival.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(exploreSelectionProvider.notifier).state = null;
    });
  }

  void _select(MapUser user) =>
      ref.read(exploreSelectionProvider.notifier).state = user.id;

  void _clearSelection() =>
      ref.read(exploreSelectionProvider.notifier).state = null;

  Future<void> _centerOnMe() async {
    final location = ref.read(myLocationProvider).valueOrNull;
    if (location != null) {
      // Centre, without touching the zoom. Somebody who pulled back to take in
      // a 10 km radius pressed this to re-find themselves in it, not to be
      // dropped back to street level.
      await _map.centerOn(location);
      return;
    }
    // No fix yet — asking again is the useful thing a "centre on me" button can
    // do, including re-raising a permission prompt that was dismissed.
    await ref.read(myLocationProvider.notifier).refresh();
    final retried = ref.read(myLocationProvider).valueOrNull;
    if (retried != null) await _map.centerOn(retried);
  }

  void _setBand(String band) {
    final filter = ref.read(discoveryFilterProvider);
    // Straight into the existing filter. The map reloads because
    // [ExploreNotifier] watches this, exactly as the Radar grid does.
    ref.read(discoveryFilterProvider.notifier).state =
        filter.copyWith(band: band);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(exploreMapStyleProvider);
    final location = ref.watch(myLocationProvider);
    final exploreAsync = ref.watch(exploreProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final me = ref.watch(meProvider).valueOrNull;
    final presence = ref.watch(presenceProvider);
    final selectedId = ref.watch(exploreSelectionProvider);
    final viewMode = ref.watch(exploreViewModeProvider);

    final explore = exploreAsync.valueOrNull;

    // Live presence over what the fetch said, so a marker's dot lights up
    // without waiting for the next reload. This is the only place the map's
    // data is touched after the API — and it changes how somebody is drawn,
    // never whether they appear.
    final users = [
      for (final user in explore?.users ?? const <MapUser>[])
        if (presence[user.id] case final online?
            when online != user.isOnline)
          MapUser(
            card: user.card.withOnline(online),
            latitude: user.latitude,
            longitude: user.longitude,
          )
        else
          user,
    ];

    final selected = selectedId == null
        ? null
        : users.where((user) => user.id == selectedId).firstOrNull;

    return Scaffold(
      backgroundColor: AppMapColors.land,
      body: style.when(
        loading: () => const _MapPlaceholder(),
        error: (error, _) => _MapFailure(
          message: error is AppException
              ? error.message
              : "Explore map couldn't load.",
          onRetry: () => ref.invalidate(exploreMapStyleProvider),
        ),
        data: (styleString) => Stack(
          children: [
            Positioned.fill(
              child: ExploreMap(
                controller: _map,
                styleString: styleString,
                users: users,
                myLocation: location.valueOrNull,
                selectedId: selectedId,
                viewMode: viewMode,
                onPersonTapped: _select,
                onBackgroundTapped: _clearSelection,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: ExploreHeader(
                      count: users.length,
                      isLoading: exploreAsync.isLoading,
                      city: explore?.city ?? me?.location?.city,
                      onFilters: () => showDiscoveryFilterSheet(context),
                    ),
                  ),
                  // Full-bleed so the pills can scroll off both edges, while
                  // the first one still lines up with the header above it.
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: ExploreRadiusBar(
                      selected: filter.band,
                      fallback: me?.location?.preferredBand,
                      onChanged: _setBand,
                    ),
                  ),
                  _sideChrome(viewMode: viewMode, locating: location.isLoading),
                  _bottomChrome(
                    selected: selected,
                    explore: explore,
                    exploreAsync: exploreAsync,
                    location: location,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideChrome({
    required ExploreViewMode viewMode,
    required bool locating,
  }) {
    return Positioned(
      top: 132,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ExploreViewToggle(
            mode: viewMode,
            onChanged: (mode) =>
                ref.read(exploreViewModeProvider.notifier).state = mode,
          ),
          const SizedBox(height: 10),
          ExploreCircleButton(
            icon: Icons.my_location,
            label: 'Center map on your location',
            busy: locating,
            onPressed: locating ? null : _centerOnMe,
          ),
        ],
      ),
    );
  }

  /// The bottom slot holds exactly one thing at a time, in priority order: an
  /// open preview, then whatever is stopping the map from being useful, then
  /// nothing.
  Widget _bottomChrome({
    required MapUser? selected,
    required ExploreState? explore,
    required AsyncValue<ExploreState> exploreAsync,
    required AsyncValue<LatLng?> location,
  }) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _bottomContent(
            selected: selected,
            explore: explore,
            exploreAsync: exploreAsync,
            location: location,
          ),
        ),
      ),
    );
  }

  Widget _bottomContent({
    required MapUser? selected,
    required ExploreState? explore,
    required AsyncValue<ExploreState> exploreAsync,
    required AsyncValue<LatLng?> location,
  }) {
    if (selected != null) {
      return ExploreProfilePreview(
        key: ValueKey('preview.${selected.id}'),
        user: selected,
        onDismiss: _clearSelection,
      );
    }

    // Location comes first: without it the map cannot centre, and every other
    // message would be answering a question the user has not reached yet.
    final locationError = location.error;
    if (locationError is LocationUnavailableException) {
      return ExploreNoticeCard(
        key: const ValueKey('notice.location'),
        icon: Icons.location_on_outlined,
        title: 'Explore needs your location',
        body: locationError.message,
        primaryLabel: locationError.isRetryable ? 'Try again' : 'Open settings',
        onPrimary: () => locationError.isRetryable
            ? ref.read(myLocationProvider.notifier).refresh()
            : ref.read(locationServiceProvider).openSettings(),
      );
    }

    // The API refused outright — offline, 500, an unexpected shape.
    if (exploreAsync.hasError) {
      final error = exploreAsync.error;
      return ExploreNoticeCard(
        key: const ValueKey('notice.error'),
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load Explore",
        body: error is AppException
            ? error.message
            : 'Check your connection and try again.',
        primaryLabel: 'Retry',
        onPrimary: () => ref.read(exploreProvider.notifier).refresh(),
      );
    }

    if (exploreAsync.isLoading && (explore?.users.isEmpty ?? true)) {
      return const ExploreLoadingPill(key: ValueKey('notice.loading'));
    }

    if (explore == null) return const SizedBox.shrink();

    if (explore.needsLocation) {
      return ExploreNoticeCard(
        key: const ValueKey('notice.needsLocation'),
        icon: Icons.public_off,
        title: 'Set your location',
        body: 'Radius needs to know roughly where you are before it can put '
            'anyone on the map.',
        primaryLabel: 'Open filters',
        onPrimary: () => showDiscoveryFilterSheet(context),
      );
    }

    // Out of reveals. The same gate the Radar grid hits, offering the same two
    // ways past it.
    if (explore.paywall != null) {
      return ExploreNoticeCard(
        key: const ValueKey('notice.paywall'),
        icon: Icons.auto_awesome,
        tone: ExploreNoticeTone.warning,
        title: 'You have seen everyone for now',
        body: explore.paywall?.message ??
            'Premium keeps the map full, with no daily limit.',
        primaryLabel: 'See everyone with Premium',
        onPrimary: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ),
        secondaryLabel: 'Watch an ad',
        onSecondary: _watchAd,
      );
    }

    if (explore.isEmpty) {
      return ExploreNoticeCard(
        key: const ValueKey('notice.empty'),
        icon: Icons.favorite_border,
        title: 'No one nearby yet',
        body: 'Nobody matches these filters at this distance. Widen the '
            'circle — your people might be one band away.',
        primaryLabel: 'Increase radius',
        onPrimary: _widenRadius,
        secondaryLabel: 'Open filters',
        onSecondary: () => showDiscoveryFilterSheet(context),
      );
    }

    return const SizedBox.shrink();
  }

  /// Step out one band, through the existing filter. Already at the widest, the
  /// full sheet is the only thing left that can help.
  void _widenRadius() {
    final filter = ref.read(discoveryFilterProvider);
    final bands = ExploreRadiusBar.bands.map((option) => option.band).toList();
    final current = filter.band ??
        ref.read(meProvider).valueOrNull?.location?.preferredBand;
    final index = bands.indexOf(current ?? '');

    if (index < 0 || index >= bands.length - 1) {
      showDiscoveryFilterSheet(context);
      return;
    }
    _setBand(bands[index + 1]);
  }

  Future<void> _watchAd() async {
    try {
      final credits = await ref
          .read(adActionsProvider)
          .watchToUnlock(placement: 'explore_unlock');
      // The credits are what open the gate, and `watchToUnlock` already
      // refreshes the Radar feed — Explore has its own provider to refresh.
      await ref.read(exploreProvider.notifier).refresh();
      if (!mounted) return;
      showRadiusToast(
        context,
        credits > 0
            ? 'Unlocked — $credits credits added'
            : 'That one was already counted',
        tone: credits > 0 ? ToastTone.success : ToastTone.neutral,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    }
  }
}

/// The ground colour, shown for the instant between the tab opening and the
/// style asset being read. Deliberately the map's own land colour, so the
/// transition into the real map is a fade-in of detail rather than a flash.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppMapColors.land,
        child: Center(child: ExploreLoadingPill(message: 'Loading the map…')),
      );
}

/// MapLibre could not be given a style at all. Nothing to render underneath, so
/// this is the one state that does replace the map.
class _MapFailure extends StatelessWidget {
  const _MapFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppMapColors.land,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ExploreNoticeCard(
            icon: Icons.map_outlined,
            title: "Explore map couldn't load",
            body: message,
            primaryLabel: 'Retry',
            onPrimary: onRetry,
          ),
        ),
      ),
    );
  }
}
