import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_provider.dart' show locationServiceProvider;
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';

/// Where the device thinks it is, right now, shown only to its owner.
///
/// ## This never leaves the device on its own
///
/// The fix taken here is held in one private field on this [State] and is
/// never written to a repository, a provider, the API, or storage of any kind
/// **unless the owner explicitly asks for it** with "Move my radar here". It
/// exists from the moment the "Me" tab is opened until the widget is disposed,
/// and that is the whole lifetime. Nothing else in the app can read it —
/// deliberately, so that a live position cannot leak into a request that was
/// only ever meant to carry the coarse anchor the person consented to.
///
/// The one write is opt-in, one tap, and clearly labelled, because the
/// alternative is worse: an anchor stranded in the wrong place has no other
/// route back. The automatic sync in `MyLocationNotifier` refuses to move an
/// anchor on a low-accuracy fix — right for something happening behind the
/// user's back, and useless to somebody on a laptop who can see the drift on
/// screen and wants it corrected.
///
/// The saved anchor — `MeLocation.latitude/longitude`, the point discovery
/// measures from — is a *different* number, and the interesting one here: the
/// distance between the two is how far the person has drifted from the location
/// their radar is still centred on. That comparison is computed on the device
/// with [Geolocator.distanceBetween]; both numbers stay local to this widget.
///
/// Radar is deliberately not refetched afterwards: `GET /discovery/nearby`
/// spends one of ten daily reveals, and pull-to-refresh on Radar is one gesture
/// away.
class LiveLocationLine extends ConsumerStatefulWidget {
  const LiveLocationLine({
    super.key,
    this.city,
    this.anchorLatitude,
    this.anchorLongitude,
  });

  /// The city the server has on file. Shown immediately; the live fix arrives
  /// underneath it a moment later.
  final String? city;

  /// The stored discovery anchor, if the location step was ever completed.
  final double? anchorLatitude;
  final double? anchorLongitude;

  @override
  ConsumerState<LiveLocationLine> createState() => _LiveLocationLineState();
}

enum _Status { loading, ready, denied, unavailable }

class _LiveLocationLineState extends ConsumerState<LiveLocationLine> {
  /// The live fix. Private, non-persisted, and gone the moment this widget is.
  Position? _fix;
  _Status _status = _Status.loading;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Only ever fired from the owner's own profile — this widget is not built
    // anywhere else.
    _locate();
  }

  @override
  void dispose() {
    // Belt and braces. The field dies with the State either way; dropping it
    // explicitly means a retained State (a leak elsewhere) still cannot keep a
    // position alive.
    _fix = null;
    super.dispose();
  }

  Future<void> _locate() async {
    if (mounted) setState(() => _status = _Status.loading);
    try {
      final fix = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _status = _Status.ready;
      });
    } catch (error) {
      // Deliberately broad. Permission refusals arrive as
      // LocationUnavailableException, but a device with no location plugin at
      // all (a test host, a desktop build) throws something else entirely, and
      // neither is worth more than a quiet line on a profile screen.
      if (!mounted) return;
      setState(() {
        _status = _isDenial(error) ? _Status.denied : _Status.unavailable;
      });
    }
  }

  bool _isDenial(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('denied') ||
        text.contains('permission') ||
        text.contains('location services');
  }

  /// "12.9716° N, 77.5946° E". Four decimals is about 11 metres — enough to be
  /// a real reading, and it is only ever shown to the person standing there.
  String _coordinates(Position fix) {
    final lat = fix.latitude;
    final lng = fix.longitude;
    return '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}';
  }

  /// How far the live fix is from the anchor the radar uses. Null when there is
  /// no anchor yet, or when the two are close enough that the difference is
  /// noise rather than news.
  String? _drift(Position fix) {
    final lat = widget.anchorLatitude;
    final lng = widget.anchorLongitude;
    if (lat == null || lng == null) return null;

    final metres = Geolocator.distanceBetween(
      lat,
      lng,
      fix.latitude,
      fix.longitude,
    );
    if (metres < 150) return 'on your saved location';
    if (metres < 1000) return '${metres.round()} m from your saved location';
    return '${(metres / 1000).toStringAsFixed(1)} km from your saved location';
  }

  /// Metres between the live fix and the stored anchor, or null when there is
  /// no anchor to compare against.
  double? _driftMetres(Position fix) {
    final lat = widget.anchorLatitude;
    final lng = widget.anchorLongitude;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(lat, lng, fix.latitude, fix.longitude);
  }

  /// Move the discovery anchor to where the device actually is.
  ///
  /// Explicit, because the automatic sync will not do it from a fix this
  /// coarse — and a laptop's fix is always coarse. Without this an account
  /// whose anchor drifted has no way to correct it short of re-onboarding.
  Future<void> _moveAnchorHere() async {
    final fix = _fix;
    if (fix == null || _saving) return;

    setState(() => _saving = true);
    try {
      final me = await ref.read(onboardingRepositoryProvider).updateLocation(
            latitude: fix.latitude,
            longitude: fix.longitude,
          );
      ref.read(meProvider.notifier).setMe(me);
      if (!mounted) return;
      showRadiusToast(
        context,
        'Radar now searches from here. Pull to refresh it.',
        tone: ToastTone.success,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.city;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (city != null && city.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.iconMuted,
              ),
              const SizedBox(width: 4),
              Text(city, style: AppTextStyles.caption),
            ],
          ),
        const SizedBox(height: 4),
        _detail(),
      ],
    );
  }

  Widget _moveAnchorAction() => TextButton(
        onPressed: _saving ? null : _moveAnchorHere,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _saving ? 'Moving…' : 'Move my radar here',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11.5,
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      );

  Widget _detail() {
    switch (_status) {
      case _Status.loading:
        return Text(
          'Locating…',
          style: AppTextStyles.caption.copyWith(fontSize: 11.5),
        );

      case _Status.ready:
        final fix = _fix!;
        final drift = _drift(fix);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _coordinates(fix),
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (drift != null)
              Text(
                drift,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.iconMuted,
                ),
              ),
            if ((_driftMetres(fix) ?? 0) >= 150) _moveAnchorAction(),
            Text(
              'Only you can see this. It stays on your device.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.iconMuted,
              ),
            ),
          ],
        );

      case _Status.denied:
      case _Status.unavailable:
        return TextButton(
          onPressed: _locate,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _status == _Status.denied
                ? 'Allow location to see where you are'
                : 'Location unavailable — tap to retry',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: AppColors.primary,
            ),
          ),
        );
    }
  }
}
