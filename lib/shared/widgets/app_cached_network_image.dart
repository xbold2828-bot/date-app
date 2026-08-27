import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/static_assets/app_icons.dart';
import '../../core/theme/app_colors.dart';

class AppCachedNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Radius used for the fallback CircleAvatar. If omitted, it's derived
  /// from [width] (or [height]) when available, otherwise defaults to 28.r
  /// to match the original avatar usage.
  final double? fallbackRadius;

  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _fallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      // Shown while the image is loading
      placeholder: (context, url) => SizedBox(
        width: 24.r,
        height: 24.r,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      // Shown on 404 / any load failure — falls back to the app logo
      // avatar instead of throwing an uncaught NetworkImageLoadException.
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    final radius = fallbackRadius ?? ((width ?? height ?? 56.r) / 2);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.tertiary,
      backgroundImage: const AssetImage(AppIcons.appLogo),
    );
  }
}

/// Fluent-call convenience: `state.avatar.toAppImage(width: 88.r, height: 88.r)`
extension CachedNetworkImageX on String? {
  Widget toAppImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double? fallbackRadius,
  }) {
    return AppCachedNetworkImage(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      fallbackRadius: fallbackRadius,
    );
  }
}
