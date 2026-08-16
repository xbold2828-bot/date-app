import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
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

/// Explore — the people you are vibing with, on the ground they are on.
///
/// Not discovery. The map shows exactly the conversations that reached VIBING:
/// threads where the other person replied. A New Energy thread is somebody who
/// reached out and has not been answered, and a location is not something to
/// hand an unanswered sender — so they are excluded, and the server is what
/// enforces that.
///
/// Which is why there is no radius control and no filter button here. Both are
/// discovery instruments: they decide who a search for strangers returns. This
/// screen has no search to narrow.
///
/// Everything is laid out over a map that never goes away. Loading, offline,
/// permission-denied, nobody-yet: the city stays on screen and the explanation
/// floats over it.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.onBrowsePeople});

  /// Take me somewhere I can meet people. The map only ever shows people who
  /// have replied, so an empty map is answered on another tab — and this screen
  /// does not own the tab bar.
  final VoidCallback? onBrowsePeople;

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
      if (!mounted) return;
      ref.read(exploreSelectionProvider.notifier).state = null;
      // Re-check where we are on every visit. "Who is around me" is a question
      // about right now, and the anchor is what the server answers it from —
      // an app that only ever asks at signup answers it from wherever the user
      // happened to be that day. Cheap when nothing moved: the notifier writes
      // nothing and refreshes nothing unless the fix has genuinely shifted.
      ref.read(myLocationProvider.notifier).refresh();
    });
  }

  void _select(MapUser user) =>
      ref.read(exploreSelectionProvider.notifier).state = user.id;

  void _clearSelection() =>
      ref.read(exploreSelectionProvider.notifier).state = null;

  /// Everybody at once, as a searchable grid.
  ///
  /// A sheet rather than a route: pushing a page would unmount the map, and
  /// rebuilding a vector map — style, tiles, marker rasters — to show a list of
  /// faces is an absurd price for a question this cheap. Picking somebody
  /// selects them and closes, landing back on a map already focused on them.
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

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(exploreMapStyleProvider);
    final location = ref.watch(myLocationProvider);
    final exploreAsync = ref.watch(exploreProvider);
    final presence = ref.watch(presenceProvider);
    final selectedId = ref.watch(exploreSelectionProvider);
    final viewMode = ref.watch(exploreViewModeProvider);

    // Live presence over what the fetch said, so a marker's dot lights up
    // without waiting for the next reload. This is the only place the map's
    // data is touched after the API — and it changes how somebody is drawn,
    // never whether they appear.
    final users = [
      for (final user in exploreAsync.valueOrNull ?? const <MapUser>[])
        if (presence[user.id] case final online?
            when online != user.isOnline)
          MapUser(
            card: user.card.withOnline(online),
            latitude: user.latitude,
            longitude: user.longitude,
            distanceMeters: user.distanceMeters,
          )
        else
          user,
    ];

    final selected = selectedId == null
        ? null
        : users.where((user) => user.id == selectedId).firstOrNull;

    // The map is the content, so the chrome that must never be covered — the
    // people strip above and the composer below — is laid out in a Column with
    // the map in the middle, and only the transient things (controls, notices,
    // preview) float over it. Stacking everything led to a composer that a
    // notice card could sit on top of.
    return Scaffold(
      backgroundColor: AppMapColors.land,
      // The composer's own padding handles the inset; resizing would also drag
      // the map up by the height of the keyboard.
      resizeToAvoidBottomInset: false,
      body: style.when(
        loading: () => const _MapPlaceholder(),
        error: (error, _) => _MapFailure(
          message: error is AppException
              ? error.message
              : "Explore map couldn't load.",
          onRetry: () => ref.invalidate(exploreMapStyleProvider),
        ),
        data: (styleString) => Column(
          children: [
            // No header. It was a glass card carrying the word "Explore" — on
            // the Explore tab — and a search button for a set the strip below
            // it already shows in full. Only the count it also carried was
            // worth keeping, and that now floats over the map where it costs
            // no layout at all.
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  ExplorePeopleStrip(
                    people: users,
                    selectedId: selectedId,
                    onSelect: _select,
                    // "All" opens the grid rather than clearing the selection.
                    // Clearing is what the grid's own "All" tile does, so the
                    // two are one gesture apart and the grid is never a
                    // one-way door.
                    onShowAll: () => _openGrid(users),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            Expanded(
              child: Stack(
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
                  Positioned(
                    top: 12,
                    left: 14,
                    child: ExploreCountPill(
                      count: users.length,
                      isLoading: exploreAsync.isLoading,
                    ),
                  ),
                  _sideChrome(viewMode: viewMode, locating: location.isLoading),
                  _notice(
                    exploreAsync: exploreAsync,
                    location: location,
                    selected: selected,
                  ),
                ],
              ),
            ),
            ExploreComposer(recipient: selected),
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

  /// Whatever is stopping the map from being useful, floated over it.
  ///
  /// One thing at a time, in the order the user would hit them: the map cannot
  /// centre without a location, cannot draw anybody if the request failed, and
  /// has nobody to draw until somebody replies.
  Widget _notice({
    required AsyncValue<List<MapUser>> exploreAsync,
    required AsyncValue<LatLng?> location,
    required MapUser? selected,
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
          child: _noticeContent(
            exploreAsync: exploreAsync,
            location: location,
            selected: selected,
          ),
        ),
      ),
    );
  }

  Widget _noticeContent({
    required AsyncValue<List<MapUser>> exploreAsync,
    required AsyncValue<LatLng?> location,
    required MapUser? selected,
  }) {
    // Somebody is in focus: the map is showing them alone, and the only thing
    // worth saying is who, and how to get back.
    if (selected != null) {
      return ExploreFocusPill(
        key: ValueKey('focus.${selected.id}'),
        name: selected.displayName,
        // How far away they actually are, not the band. Falls back to the band
        // on a payload that predates the number.
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
      // Not a failure — just nobody here yet. The map only ever shows people
      // who replied to you, so the way to fill it is to get a conversation
      // going, which lives on another tab.
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
