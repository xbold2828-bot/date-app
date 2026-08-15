import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, Position;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../core/errors/app_exceptions.dart';
import '../data/models/user_model.dart';
import '../data/services/location_service.dart';
import 'core_providers.dart';
import 'explore_provider.dart';
import 'profile_provider.dart';

/// Where the app believes the user is — the **anchor**.
///
/// Deliberately its own file rather than part of Explore's. The anchor is not an
/// Explore concept: it is the point `GET /discovery/nearby` measures Radar from,
/// the point Explore draws "you are here" at, and the point every distance band
/// in the app is derived from. Living inside `explore_provider.dart` is what let
/// an Explore detail reach into Radar and break it — see the note on
/// [MyLocationNotifier._reanchorIfMoved] about the discovery feed.
///
/// **Nothing here may touch Radar's feed.** Radar is paid for by the reveal
/// allowance; see below.

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// The anchor, kept honest against the device.
///
/// ## Why the marker and the query must be the same point
///
/// The server ranks and filters everybody by distance from `me.location.point`.
/// Explore draws a "you are here" marker. If the marker comes from the device's
/// GPS and the anchor comes from whatever was stored at signup, the two drift
/// apart the moment the user moves — and the map is then simply lying: it draws
/// them on one street while presenting people selected, sorted and
/// distance-banded from another.
///
/// That is what shipped originally. `PATCH /location` was called from precisely
/// one place, onboarding step 5, so the anchor froze at signup while the marker
/// tracked the device.
///
/// So this takes a device fix, re-anchors the account when it has genuinely
/// moved, and returns the anchor. Marker and query cannot disagree, because they
/// are the same number.
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

  /// Worst reported accuracy still trusted to move the anchor, in metres.
  ///
  /// A browser with no GPS answers `getCurrentPosition` from the IP address,
  /// which can be a different suburb or a different city and reports accuracy in
  /// the thousands of metres. Moving a real anchor to that is worse than leaving
  /// it alone: it silently relocates the account, and then Radar searches around
  /// somewhere the user has never been. A coarse fix is still better than no
  /// anchor at all, so this only guards accounts that already have one.
  static const double _minAccuracyMetres = 1000;

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

    // Do not relocate somebody on the strength of an IP-derived guess.
    if (hasPoint && fix.accuracy > _minAccuracyMetres) {
      return LatLng(stored.latitude!, stored.longitude!);
    }

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

      // Explore is free to reload — it reads the user's own conversations.
      ref.read(exploreProvider.notifier).refresh();

      // **Radar is deliberately NOT reloaded here.**
      //
      // `GET /discovery/nearby` spends a reveal from a 10-per-day free
      // allowance. Refreshing it on every re-anchor burned that allowance in a
      // handful of Explore visits, after which the endpoint answered 402 and
      // the Radar grid rendered the paywall with no profiles at all — which is
      // exactly what "I cannot see anyone in Radar any more" turned out to be.
      //
      // `HomeScreen.didChangeAppLifecycleState` already refuses to refresh it
      // on resume for this same reason. Radar is a snapshot until it is pulled
      // to refresh, and a background location sync has no business spending
      // somebody's daily allowance on their behalf.

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
