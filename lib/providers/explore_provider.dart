import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/map_user_model.dart';
import '../data/services/map_style_service.dart';
import 'core_providers.dart';

/// Explore state: the map's people and the chrome around them.
///
/// Scoped deliberately tightly. The anchor lives in `location_provider.dart`
/// because it belongs to the whole app, and **nothing here reaches into
/// Radar** — Radar is discovery, this is the vibing inbox on a map, and the two
/// share no state beyond the user's own location.

final mapStyleServiceProvider =
    Provider<MapStyleService>((ref) => MapStyleService());

/// The finished MapLibre style document.
///
/// Not autoDispose: leaving the tab and coming back must not hand MapLibre a
/// fresh string, which is what forces a full re-fetch of every vector tile.
final exploreMapStyleProvider =
    FutureProvider<String>((ref) => ref.watch(mapStyleServiceProvider).load());

/// The people on the Explore map: whoever the user is **vibing** with.
///
/// Not discovery. A vibing conversation is one both people have spoken in — the
/// recipient replied — and that mutual consent is the entire basis for putting
/// somebody on a map. New Energy threads are excluded on purpose: one person
/// has reached out and not been answered, and a location is not something to
/// hand an unanswered sender.
///
/// Which is why there is no filter, no radius and no paywall state here. Those
/// all belong to discovery: they decide who a *stranger* search returns. This
/// list is simply the user's own conversations, so there is nothing to narrow
/// and nothing to charge for.
class ExploreNotifier extends AsyncNotifier<List<MapUser>> {
  @override
  Future<List<MapUser>> build() =>
      ref.watch(chatRepositoryProvider).mapPeople();

  Future<void> refresh() async {
    state = const AsyncLoading<List<MapUser>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).mapPeople(),
    );
  }
}

final exploreProvider =
    AsyncNotifierProvider<ExploreNotifier, List<MapUser>>(ExploreNotifier.new);

/// The person whose preview is open, or null.
///
/// Held outside the map widget so a rebuild of the screen — a filter change, a
/// presence tick — does not close a sheet the user is reading.
final exploreSelectionProvider = StateProvider<String?>((ref) => null);

/// Flat or tilted. See [ExploreCamera] for the pitch each one means.
enum ExploreViewMode { flat, tilted }

final exploreViewModeProvider =
    StateProvider<ExploreViewMode>((ref) => ExploreViewMode.tilted);

/// Camera constants, in one place so the map, the toggle and the centre button
/// cannot disagree about what "3D" or "close enough to see buildings" means.
class ExploreCamera {
  const ExploreCamera._();

  /// City scale: streets legible, a few hundred metres of people in frame.
  static const double defaultZoom = 13.5;

  /// Where a tap on a person or a cluster settles. Past 14.5, which is where
  /// the style starts extruding buildings — tapping someone should reveal the
  /// 3D city, not just a bigger flat one.
  static const double focusZoom = 15.5;

  static const double minZoom = 3;
  static const double maxZoom = 19;

  /// Enough tilt to read building height without the horizon eating the frame
  /// or markers near the top collapsing into each other.
  static const double tiltedPitch = 42;
  static const double flatPitch = 0;

  static double pitchFor(ExploreViewMode mode) =>
      mode == ExploreViewMode.tilted ? tiltedPitch : flatPitch;

  /// Long enough to read as a move rather than a cut; short enough that the
  /// 2D/3D toggle still feels like a button.
  static const Duration transition = Duration(milliseconds: 620);
}
