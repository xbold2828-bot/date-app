import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_helper.dart';

class BannerAdWidget extends StatefulWidget {
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
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
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
      // Size changed while visible: reload with the new size.
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
    final ad = _ad;
    if (!widget.visible || ad == null || !_loaded) {
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