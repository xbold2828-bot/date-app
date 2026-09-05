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

  @override
  void initState() {
    super.initState();
    if (widget.visible) _loadAd();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.visible && _ad == null) {
      _loadAd();
    } else if (!widget.visible && _ad != null) {
      _disposeAd();
    } else if (widget.visible && oldWidget.size != widget.size) {
      _disposeAd();
      _loadAd();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _ad = AdHelper.createBannerAd(
      size: widget.size,
      onLoaded: (_) {
        if (mounted) setState(() => _loaded = true);
      },
      onFailedToLoad: (_, _) => _disposeAd(),
    );
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() => _loaded = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isUserHavePremiumProvider);
    final ad = _ad;

    if (isPremium || !widget.visible || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }

    final box = SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );

    if (widget.margin == null) return box;
    return Padding(padding: widget.margin!, child: box);
  }
}