import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// One person's face, as a circle.
///
/// Used by the top strip, the grid and the composer, which is the whole point:
/// the same person has to be recognisably the same object in all three, or
/// picking somebody in the grid and then finding them in the strip becomes a
/// puzzle. Ring, size and fallback all live here so they cannot drift.
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

  /// Draws the oxblood-to-plum ring that marks the person the map is showing.
  final bool selected;

  final bool isOnline;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    // The ring sits outside the photo rather than over it, so selecting
    // somebody does not crop their face.
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
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppMapColors.markerStart,
                        AppMapColors.markerEnd,
                      ],
                    )
                  : null,
              border: selected
                  ? null
                  : Border.all(color: AppColors.inputBorder, width: 1),
            ),
            padding: EdgeInsets.all(selected ? ringWidth : 1),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
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
      // These are thumbnails at 40–56 pt. Decoding a full-resolution portrait
      // for each of a hundred grid cells is how a grid janks on a mid-range
      // phone; the ceiling is generous enough for a 3x screen.
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppMapColors.markerStart, AppMapColors.markerEnd],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: AppTextStyles.avatarInitial(inner * 0.42),
        ),
      );
}
