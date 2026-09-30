import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../providers/is_user_have_premium_provider.dart';
import '../ad_helper.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({
    super.key,
    this.visible = true,
    this.size = AdSize.banner,
    this.margin,
  });

  final bool visible;
  final AdSize size;
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  bool get _isPremium => ref.read(isUserHavePremiumProvider);

  @override
  void initState() {
    super.initState();
    if (widget.visible && !_isPremium) _loadAd();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A different size needs a different ad.
    if (oldWidget.size != widget.size) _releaseAd();

    // When hidden, we keep the loaded ad and just stop drawing it.
    // This avoids creating and destroying the native view on every tab tap.
    if (widget.visible && _ad == null && !_isPremium) _loadAd();
  }

  @override
  void dispose() {
    _disposeLater(_ad);
    _ad = null;
    super.dispose();
  }

  void _loadAd() {
    _ad = AdHelper.createBannerAd(
      size: widget.size,
      onLoaded: (ad) {
        // Ignore callbacks from an ad we already replaced or released.
        if (!mounted || !identical(ad, _ad)) return;
        setState(() => _loaded = true);
      },
      onFailedToLoad: (ad, _) {
        // AdHelper already disposed this ad. Only clear our reference.
        if (!mounted || !identical(ad, _ad)) return;
        setState(() {
          _ad = null;
          _loaded = false;
        });
      },
    );
  }

  /// Remove the ad from the screen FIRST, then destroy it a moment later.
  /// Disposing while the AdWidget is still on screen is what crashes the
  /// native platform view.
  void _releaseAd() {
    final ad = _ad;
    _ad = null;
    _loaded = false;
    if (mounted) setState(() {});
    _disposeLater(ad);
  }

  void _disposeLater(BannerAd? ad) {
    if (ad == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), ad.dispose);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium can change while the app is running.
    ref.listen(isUserHavePremiumProvider, (_, next) {
      if (next) {
        _releaseAd();
      } else if (widget.visible && _ad == null) {
        _loadAd();
      }
    });

    final isPremium = ref.watch(isUserHavePremiumProvider);
    final ad = _ad;

    if (isPremium || !widget.visible || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }

    final box = SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(key: ObjectKey(ad), ad: ad),
    );

    if (widget.margin == null) return box;
    return Padding(padding: widget.margin!, child: box);
  }
}