import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, Position;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../core/errors/app_exceptions.dart';
import '../data/models/map_user_model.dart';
import '../data/models/user_model.dart';
import '../data/services/location_service.dart';
import '../data/services/map_style_service.dart';
import 'core_providers.dart';
import 'match_provider.dart';
import 'profile_provider.dart';

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

/// Where the app believes I am — the **anchor**, not the raw device fix.
///
/// ## Why these have to be the same point
///
/// The server ranks and filters everybody by distance from `me.location.point`.
/// The map draws a "you are here" marker. If the marker comes from the device's
/// GPS and the anchor comes from whatever was stored at signup, the two drift
/// apart the moment the user moves — and then the map is simply lying: it
/// draws them on one street while presenting people who were selected, sorted
/// and distance-banded from another.
///
/// That is exactly what shipped. `PATCH /location` was called from precisely
/// one place, onboarding step 5, so the anchor froze at signup and never moved
/// again while the marker tracked the device. On one machine it was worse
/// still: every test account got the identical device fix, so "you" appeared in
/// the same spot for all of them, which reads as a hardcoded location.
///
/// So this notifier does both jobs in one place. It takes a device fix,
/// re-anchors the account when the fix has materially moved, and then returns
/// the anchor. Marker and query cannot disagree, because they are the same
/// number.
class MyLocationNotifier extends AsyncNotifier<LatLng?> {
  /// How far the device has to have moved before the anchor is rewritten.
  ///
  /// Below this, a rewrite buys nothing and costs a request: consumer GPS
  /// wanders by tens of metres while sitting still, and every write invalidates
  /// the discovery cache keyed on the resulting geohash.
  static const double _resyncMetres = 150;

  /// Re-anchor regardless once the stored point is this old, so an account that
  /// travelled while the app was closed is not left measuring from another city.
  static const Duration _resyncAfter = Duration(minutes: 30);

  @override
  Future<LatLng?> build() => _read();

  Future<LatLng?> _read() async {
    final me = await ref.read(meProvider.future);
    final stored = me.location;

    Position? fix;
    try {
      fix = await ref.read(locationServiceProvider).current();
    } on LocationUnavailableException {
      // A refused or unavailable fix is only fatal if there is nothing stored
      // to fall back on. An account that finished onboarding has an anchor, and
      // showing that beats refusing to draw the map at all — the anchor is what
      // the results were computed from either way.
      if (stored != null && stored.hasPoint) {
        return LatLng(stored.latitude!, stored.longitude!);
      }
      rethrow;
    }

    final anchor = await _reanchorIfMoved(fix, stored);
    return anchor ?? LatLng(fix.latitude, fix.longitude);
  }

  /// Writes the new position when it matters, and returns the anchor to draw.
  Future<LatLng?> _reanchorIfMoved(Position fix, MeLocation? stored) async {
    final hasPoint = stored != null && stored.hasPoint;
    final movedFarEnough = !hasPoint ||
        Geolocator.distanceBetween(
              stored.latitude!,
              stored.longitude!,
              fix.latitude,
              fix.longitude,
            ) >
            _resyncMetres;
    final isStale = stored?.updatedAt == null ||
        DateTime.now().difference(stored!.updatedAt!) > _resyncAfter;

    if (!movedFarEnough && !isStale) {
      return LatLng(stored.latitude!, stored.longitude!);
    }

    try {
      final updated =
          await ref.read(onboardingRepositoryProvider).updateLocation(
                latitude: fix.latitude,
                longitude: fix.longitude,
                // Sent back unchanged so the radius the user chose survives the
                // write. The server no longer clears an omitted band, but a
                // client that outlives a server rollback should not widen
                // somebody's discovery to the 50 km fallback behind their back.
                preferredBand: stored?.preferredBand,
              );
      ref.read(meProvider.notifier).setMe(updated);

      // Everything distance-ranked was computed from the old anchor.
      ref.read(exploreProvider.notifier).refresh();
      ref.read(nearbyProvider.notifier).refresh();

      final location = updated.location;
      if (location != null && location.hasPoint) {
        return LatLng(location.latitude!, location.longitude!);
      }
    } on AppException {
      // Offline, or the server refused. The map is still worth drawing from
      // whatever anchor we have; the next open will try again.
      if (hasPoint) return LatLng(stored.latitude!, stored.longitude!);
    }
    return null;
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
