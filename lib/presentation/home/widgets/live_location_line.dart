import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_provider.dart' show locationServiceProvider;
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';

class LiveLocationLine extends ConsumerStatefulWidget {
  const LiveLocationLine({
    super.key,
    this.city,
    this.anchorLatitude,
    this.anchorLongitude,
  });

  final String? city;

  final double? anchorLatitude;
  final double? anchorLongitude;

  @override
  ConsumerState<LiveLocationLine> createState() => _LiveLocationLineState();
}

enum _Status { loading, ready, denied, unavailable }

class _LiveLocationLineState extends ConsumerState<LiveLocationLine> {
  Position? _fix;
  _Status _status = _Status.loading;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
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

  String _coordinates(Position fix) {
    final lat = fix.latitude;
    final lng = fix.longitude;
    return '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}';
  }

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

  double? _driftMetres(Position fix) {
    final lat = widget.anchorLatitude;
    final lng = widget.anchorLongitude;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(lat, lng, fix.latitude, fix.longitude);
  }

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