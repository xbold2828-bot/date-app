import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_format.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/explore_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/explore_composer.dart';
import '../widgets/explore_controls.dart';
import '../widgets/explore_map.dart';
import '../widgets/explore_people_grid.dart';
import '../widgets/explore_people_strip.dart';
import '../widgets/explore_states.dart';

/// Shows the people you are vibing with on a map.
///
/// Only conversations where the other person replied appear here.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.onBrowsePeople});

  /// Switches to the tab where the user can meet people.
  final VoidCallback? onBrowsePeople;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _map = ExploreMapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(exploreSelectionProvider.notifier).state = null;
      ref.read(myLocationProvider.notifier).refresh();
    });
  }

  void _select(MapUser user) =>
      ref.read(exploreSelectionProvider.notifier).state = user.id;

  void _clearSelection() =>
      ref.read(exploreSelectionProvider.notifier).state = null;

  /// Opens the people grid in a sheet. A sheet is used instead of a route so
  /// the map is not unmounted.
  Future<void> _openGrid(List<MapUser> people) async {
    if (people.isEmpty) return;
    await showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => ExplorePeopleGrid(
        people: people,
        selectedId: ref.read(exploreSelectionProvider),
        onClose: () => Navigator.pop(sheetContext),
        onSelect: (person) {
          _select(person);
          Navigator.pop(sheetContext);
        },
        onShowAll: () {
          _clearSelection();
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Future<void> _centerOnMe() async {
    final location = ref.read(myLocationProvider).valueOrNull;
    if (location != null) {
      await _map.goToMe(location);
      return;
    }

    await ref.read(myLocationProvider.notifier).refresh();
    if (!mounted) return;

    final retried = ref.read(myLocationProvider).valueOrNull;
    if (retried != null) await _map.goToMe(retried);
  }

  /// Applies live online status on top of the fetched users.
  List<MapUser> _withPresence(
      List<MapUser> fetched,
      Map<String, bool> presence,
      ) {
    return [
      for (final user in fetched)
        if (presence[user.id] case final online? when online != user.isOnline)
          MapUser(
            card: user.card.withOnline(online),
            latitude: user.latitude,
            longitude: user.longitude,
            distanceMeters: user.distanceMeters,
          )
        else
          user,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(exploreMapStyleProvider);
    final location = ref.watch(myLocationProvider);
    final exploreAsync = ref.watch(exploreProvider);
    final presence = ref.watch(presenceProvider);
    final selectedId = ref.watch(exploreSelectionProvider);
    final viewMode = ref.watch(exploreViewModeProvider);

    final users = _withPresence(
      exploreAsync.valueOrNull ?? const <MapUser>[],
      presence,
    );

    final selected = selectedId == null
        ? null
        : users.where((user) => user.id == selectedId).firstOrNull;

    return Scaffold(
      backgroundColor: AppMapColors.land,
      resizeToAvoidBottomInset: false,
      body: style.when(
        loading: () => const _MapPlaceholder(),
        error: (error, _) => _MapFailure(
          message: error is AppException
              ? error.message
              : "Explore map couldn't load.",
          onRetry: () => ref.invalidate(exploreMapStyleProvider),
        ),
        data: (styleString) => Stack(
          fit: StackFit.expand,
          children: [
            // The map always fills the screen, so its size never changes.
            // Resizing a native map view is what caused the crash.
            ExploreMap(
              key: const ValueKey('explore-map'),
              controller: _map,
              styleString: styleString,
              users: users,
              myLocation: location.valueOrNull,
              selectedId: selectedId,
              viewMode: viewMode,
              onPersonTapped: _select,
              onBackgroundTapped: _clearSelection,
            ),
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: ExplorePeopleStrip(
                      people: users,
                      selectedId: selectedId,
                      onSelect: _select,
                      onShowAll: () => _openGrid(users),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: 12,
                        left: 14,
                        child: ExploreCountPill(
                          count: users.length,
                          isLoading: exploreAsync.isLoading,
                        ),
                      ),
                      _buildSideControls(
                        viewMode: viewMode,
                        locating: location.isLoading,
                      ),
                      _buildNotice(
                        exploreAsync: exploreAsync,
                        location: location,
                        selected: selected,
                        // With extendBody on, the screen runs under the
                        // bottom nav (and banner). The composer already pads
                        // for it; when it is hidden the notice must too, so it
                        // sits above the nav.
                        bottomInset: selected == null
                            ? MediaQuery.paddingOf(context).bottom
                            : 0,
                      ),
                    ],
                  ),
                ),
                ExploreComposer(recipient: selected),
              ],
            ),
          ],
        ),
      ),
    ).withGlobalBackHandler(context);
  }

  Widget _buildSideControls({
    required ExploreViewMode viewMode,
    required bool locating,
  }) {
    return Positioned(
      top: 12,
      right: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ExploreViewToggle(
            mode: viewMode,
            onChanged: (mode) =>
            ref.read(exploreViewModeProvider.notifier).state = mode,
          ),
          const SizedBox(height: 10),
          ExploreZoomButtons(
            onZoomIn: () => _map.zoomBy(1),
            onZoomOut: () => _map.zoomBy(-1),
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

  Widget _buildNotice({
    required AsyncValue<List<MapUser>> exploreAsync,
    required AsyncValue<LatLng?> location,
    required MapUser? selected,
    required double bottomInset,
  }) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18 + bottomInset,
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
          child: _noticeContent(
            exploreAsync: exploreAsync,
            location: location,
            selected: selected,
          ),
        ),
      ),
    );
  }

  /// Picks the one notice to show, in priority order.
  Widget _noticeContent({
    required AsyncValue<List<MapUser>> exploreAsync,
    required AsyncValue<LatLng?> location,
    required MapUser? selected,
  }) {
    if (selected != null) {
      return ExploreFocusPill(
        key: ValueKey('focus.${selected.id}'),
        name: selected.displayName,
        distance: formatDistanceAway(selected.distanceMeters) ??
            (selected.distanceBand.isEmpty
                ? null
                : '${selected.distanceBand} away'),
        onShowEveryone: _clearSelection,
      );
    }

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

    final people = exploreAsync.valueOrNull;
    if (exploreAsync.isLoading && (people?.isEmpty ?? true)) {
      return const ExploreLoadingPill(key: ValueKey('notice.loading'));
    }

    if (people != null && people.isEmpty) {
      return ExploreNoticeCard(
        key: const ValueKey('notice.empty'),
        icon: Icons.forum_outlined,
        title: 'Nobody on your map yet',
        body: 'People show up here once you are both talking — when someone '
            'replies to you, they appear on the map.',
        primaryLabel: widget.onBrowsePeople == null ? null : 'Find people',
        onPrimary: widget.onBrowsePeople,
      );
    }

    return const SizedBox.shrink();
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppMapColors.land,
    child: Center(child: ExploreLoadingPill(message: 'Loading the map…')),
  );
}

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