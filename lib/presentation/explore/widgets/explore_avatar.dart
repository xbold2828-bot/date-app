import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A person's face as a circle. Used by the strip, the grid and the composer
/// so the same person looks the same everywhere.
class ExploreAvatar extends StatelessWidget {
  const ExploreAvatar({
    super.key,
    required this.name,
    required this.size,
    this.photoUrl,
    this.selected = false,
    this.isOnline = false,
    this.showOnlineDot = true,
  });

  final String name;
  final double size;
  final String? photoUrl;

  /// Draws a blue ring around the person the map is showing.
  final bool selected;

  final bool isOnline;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    const ringWidth = 2.4;
    final inner = size - (ringWidth + 2) * 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.blue : null,
              border: selected
                  ? null
                  : Border.all(color: AppColors.inputBorder, width: 1),
            ),
            padding: EdgeInsets.all(selected ? ringWidth : 1),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
              ),
              padding: const EdgeInsets.all(1.6),
              child: ClipOval(child: _photo(inner)),
            ),
          ),
          if (isOnline && showOnlineDot)
            Positioned(
              right: 0,
              bottom: 1,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                constraints: const BoxConstraints(minWidth: 9, minHeight: 9),
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panel, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photo(double inner) {
    final url = photoUrl;
    if (url == null || url.isEmpty) return _initial(inner);

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: inner,
      height: inner,
      // Thumbnails only, so a large grid does not decode full-size photos.
      memCacheWidth: 180,
      placeholder: (_, _) => _initial(inner),
      errorWidget: (_, _, _) => _initial(inner),
    );
  }

  Widget _initial(double inner) => Container(
    width: inner,
    height: inner,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.blue,
    ),
    alignment: Alignment.center,
    child: Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: AppTextStyles.avatarInitial(inner * 0.42),
    ),
  );
}