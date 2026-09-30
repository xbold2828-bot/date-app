import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, Position;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../core/errors/app_exceptions.dart';
import '../data/models/user_model.dart';
import '../data/services/location_service.dart';
import 'core_providers.dart';
import 'explore_provider.dart';
import 'profile_provider.dart';

final locationServiceProvider =
Provider<LocationService>((ref) => const LocationService());

/// The user's anchor location: the point the server measures distances from
/// and the point the map draws "you are here" at.
///
/// It reads a device fix and updates the account only if the user has actually
/// moved, so the marker and the server query always use the same point.
class MyLocationNotifier extends AsyncNotifier<LatLng?> {
  /// Minimum movement before the stored location is rewritten.
  static const double _resyncMetres = 150;

  /// Rewrite the stored location anyway once it is this old.
  static const Duration _resyncAfter = Duration(minutes: 30);

  /// Fixes less accurate than this (for example IP-based ones) never move an
  /// existing anchor.
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
      // Fall back to the stored location if there is one.
      if (stored != null && stored.hasPoint) {
        return LatLng(stored.latitude!, stored.longitude!);
      }
      rethrow;
    }

    final anchor = await _reanchorIfMoved(fix, stored);
    return anchor ?? LatLng(fix.latitude, fix.longitude);
  }

  /// Saves the new position if it matters and returns the anchor to use.
  Future<LatLng?> _reanchorIfMoved(Position fix, MeLocation? stored) async {
    final hasPoint = stored != null && stored.hasPoint;

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
      );
      ref.read(meProvider.notifier).setMe(updated);
      ref.read(exploreProvider.notifier).refresh();

      // Radar is intentionally not refreshed here. Its endpoint spends a
      // limited daily allowance, and a background location sync must not use
      // it up.

      final location = updated.location;
      if (location != null && location.hasPoint) {
        return LatLng(location.latitude!, location.longitude!);
      }
    } on AppException {
      // Offline or rejected: keep using the stored anchor.
      if (hasPoint) return LatLng(stored.latitude!, stored.longitude!);
    }
    return null;
  }

  /// Asks again, including the permission prompt.
  Future<void> refresh() async {
    state = const AsyncLoading<LatLng?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_read);
  }

  /// Why the fix failed, or null if it did not.
  LocationFailure? get failure {
    final error = state.error;
    return error is LocationUnavailableException ? error.reason : null;
  }
}

final myLocationProvider =
AsyncNotifierProvider<MyLocationNotifier, LatLng?>(MyLocationNotifier.new);