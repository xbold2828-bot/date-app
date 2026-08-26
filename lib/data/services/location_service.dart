import 'package:geolocator/geolocator.dart';

import '../../core/errors/app_exceptions.dart';

/// The one place the app talks to the device's GPS.
///
/// Onboarding (step 5) and Explore both need a fix, and before this existed the
/// permission dance lived inline in the onboarding screen — so a second caller
/// meant a second, subtly different copy of it. Every failure comes back as a
/// [LocationUnavailableException] carrying a [LocationFailure], because the two
/// callers want to say different things about the same refusal.
///
/// This does **not** send anything anywhere. Uploading a position is
/// `OnboardingRepository.updateLocation`; what the map draws is the generalized
/// position the backend hands back, never the raw fix taken here.
class LocationService {
  const LocationService();

  /// A position for the device, asking for permission if it hasn't been asked.
  ///
  /// [timeLimit] guards the case where permission is granted but no fix ever
  /// arrives — indoors, or on an emulator with no mock location set — which
  /// otherwise leaves the caller on a spinner forever.
  Future<Position> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    await ensurePermission();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } on LocationUnavailableException {
      rethrow;
    } catch (_) {
      // A timeout is by far the likeliest cause, and the last known fix is a
      // better answer than an error screen when there is one.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationUnavailableException(
        LocationFailure.unavailable,
        "Couldn't get your location. Please try again.",
      );
    }
  }

  /// Throws unless location services are on and permission is granted.
  ///
  /// Split out so a screen can check before showing a map it may not be able
  /// to fill.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException(
        LocationFailure.serviceDisabled,
        'Turn on location services to see who is around you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        LocationFailure.deniedForever,
        'Location is turned off for cozune. Enable it in your device '
        'settings to discover people near you.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException(
        LocationFailure.denied,
        'Allow location to discover people around you.',
      );
    }
  }

  /// Opens the OS settings page where a permanent denial can be undone.
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
