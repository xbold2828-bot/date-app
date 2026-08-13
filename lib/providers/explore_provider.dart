import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../core/errors/app_exceptions.dart';
import '../data/models/map_user_model.dart';
import '../data/services/location_service.dart';
import '../data/services/map_style_service.dart';
import 'core_providers.dart';
import 'match_provider.dart';

/// Explore state: the map's people, plus the device fix that centres it.
///
/// Everything about *who is eligible* stays where it already lives — the
/// backend decides, [discoveryFilterProvider] parameterises it, and this file
/// only asks. There is deliberately no client-side filtering of the result set
/// anywhere below: a map that hid people the API returned would be a second,
/// silently diverging copy of the discovery rules.

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

final mapStyleServiceProvider =
    Provider<MapStyleService>((ref) => MapStyleService());

/// The finished MapLibre style document.
///
/// Not autoDispose: leaving the tab and coming back must not hand MapLibre a
/// fresh string, which is what forces a full re-fetch of every vector tile.
final exploreMapStyleProvider =
    FutureProvider<String>((ref) => ref.watch(mapStyleServiceProvider).load());

/// Where the device says we are.
///
/// Only ever used to point the camera and to draw the "you" marker. It is never
/// sent anywhere — Explore reads positions, it does not publish them. The
/// stored location the backend matches against is the one onboarding uploaded.
class MyLocationNotifier extends AsyncNotifier<LatLng?> {
  @override
  Future<LatLng?> build() => _read();

  Future<LatLng?> _read() async {
    final position = await ref.read(locationServiceProvider).current();
    return LatLng(position.latitude, position.longitude);
  }

  /// Re-ask, including the permission prompt. Backs both "Try again" on the
  /// permission state and the centre-on-me button after a denial.
  Future<void> refresh() async {
    state = const AsyncLoading<LatLng?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_read);
  }

  /// The reason the fix failed, or null while it is fine.
  LocationFailure? get failure {
    final error = state.error;
    return error is LocationUnavailableException ? error.reason : null;
  }
}

final myLocationProvider =
    AsyncNotifierProvider<MyLocationNotifier, LatLng?>(MyLocationNotifier.new);

/// The map's people, plus the gates the API can put in front of them.
///
/// [paywall] and [needsLocation] mirror [NearbyState] exactly, because they
/// come from the same endpoint family and the same two failures: the reveal
/// allowance running out, and an account with no location set. Modelling them
/// as state rather than as errors is what lets the map stay on screen
/// underneath the card explaining itself.
class ExploreState {
  const ExploreState({
    this.users = const [],
    this.city,
    this.paywall,
    this.needsLocation = false,
  });

  final List<MapUser> users;
  final String? city;
  final EntitlementRequiredException? paywall;
  final bool needsLocation;

  bool get isEmpty => users.isEmpty && paywall == null && !needsLocation;
}

class ExploreNotifier extends AsyncNotifier<ExploreState> {
  @override
  Future<ExploreState> build() {
    // The single seam that keeps Explore honest: the radius selector and the
    // existing DiscoveryFilterSheet both write here, and both reload the map.
    ref.watch(discoveryFilterProvider);
    return _load();
  }

  Future<ExploreState> _load() async {
    final filter = ref.read(discoveryFilterProvider);
    try {
      final page = await ref.read(discoveryRepositoryProvider).explore(
            intent: filter.intent,
            band: filter.band,
            genders: filter.genders,
            minAge: filter.isFullAgeRange ? null : filter.minAge,
            maxAge: filter.isFullAgeRange ? null : filter.maxAge,
            verifiedOnly: filter.verifiedOnly,
            onlineOnly: filter.onlineOnly,
            recentlyActive: filter.recentlyActive,
            relationshipStatus: filter.relationshipStatus,
            personalityTags: filter.personalityTags,
            preferenceTags: filter.preferenceTags,
          );
      return ExploreState(users: page.items, city: page.city);
    } on EntitlementRequiredException catch (e) {
      return ExploreState(paywall: e);
    } on BadRequestException {
      return const ExploreState(needsLocation: true);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<ExploreState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final exploreProvider =
    AsyncNotifierProvider<ExploreNotifier, ExploreState>(ExploreNotifier.new);

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
