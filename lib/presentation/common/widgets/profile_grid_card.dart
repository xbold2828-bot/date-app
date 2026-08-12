import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// The palette that stands in for a missing photo. Warm, muted, and distinct
/// enough that two adjacent cards never look like the same person.
const List<List<Color>> kAvatarGradients = [
  [Color(0xFFB85C6B), Color(0xFF7E2230)],
  [Color(0xFFC88A3D), Color(0xFF8F5A17)],
  [Color(0xFF7C6BB8), Color(0xFF4A3E80)],
  [Color(0xFF4E8F86), Color(0xFF26564F)],
  [Color(0xFFB8563D), Color(0xFF7C2E1B)],
  [Color(0xFF7B8FB8), Color(0xFF3E5580)],
  [Color(0xFFB84E86), Color(0xFF7C2356)],
  [Color(0xFF8FB85C), Color(0xFF54761F)],
];

/// A gradient derived from an index, so the same person keeps the same colour
/// as they move around a list.
LinearGradient avatarGradient(int index) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: kAvatarGradients[index % kAvatarGradients.length],
    );

/// One person in the discovery grid.
///
/// Replaces the two near-identical implementations that had grown in the
/// Radar and Likes tabs.
///
/// Distance is always shown as a *band* — never a number. That is a promise
/// the product makes about privacy, and it is enforced here by only ever
/// accepting a pre-banded string.
class ProfileGridCard extends StatelessWidget {
  const ProfileGridCard({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.onTap,
    this.age,
    this.distanceBand,
    this.photoUrl,
    this.isOnline = false,
    this.isVerified = false,
    this.blurred = false,
  });

  final String name;
  final int? age;

  /// e.g. "2-5 km". Never a precise distance.
  final String? distanceBand;

  final String? photoUrl;
  final bool isOnline;
  final bool isVerified;

  /// Picks the fallback gradient. Usually the card's position in the grid.
  final int colorIndex;

  /// Hides who this is behind a blur, for a card the viewer has not unlocked.
  ///
  /// **This is a presentation effect, not a security boundary.** It obscures
  /// whatever the server chose to send; it cannot protect a photo the response
  /// already contains. A locked card should carry either no photo URL at all,
  /// or a downscaled thumbnail with no recoverable detail — the blur then has
  /// nothing left to give away. Never rely on this alone to gate a paywall.
  final bool blurred;

  final VoidCallback onTap;

  String get _title => age != null ? '$name, $age' : name;

  @override
  Widget build(BuildContext context) {
    final semantics = blurred
        ? 'Hidden profile, unlock to see who this is'
        : [
            _title,
            if (isVerified) 'verified',
            if (isOnline) 'online now',
            if (distanceBand != null && distanceBand!.isNotEmpty)
              '$distanceBand away',
          ].join(', ');

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: photoUrl == null ? avatarGradient(colorIndex) : null,
              color: photoUrl != null ? AppColors.inputBorder : null,
              borderRadius: BorderRadius.circular(16),
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                      // Blurring the decoration itself rather than wrapping the
                      // card keeps the name, dots and pips crisp on top.
                      filterQuality: FilterQuality.low,
                    )
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (blurred && photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const ColoredBox(color: Color(0x14000000)),
                    ),
                  ),

                if (photoUrl == null)
                  Center(
                    child: blurred
                        ? const SizedBox.shrink()
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTextStyles.avatarInitial(30).copyWith(
                              color: AppColors.white.withValues(alpha: 0.92),
                            ),
                          ),
                  ),

                // Scrim. Without it the name is unreadable over a light photo.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAE140806)],
                      stops: [0.46, 1],
                    ),
                  ),
                ),

                // Presence still shows on a locked card: "someone nearby is
                // online right now" is the reason to unlock, and it gives
                // nothing away about who.
                if (isOnline)
                  const Positioned(top: 8, left: 8, child: _PresenceDot()),

                if (isVerified && !blurred)
                  const Positioned(top: 7, right: 7, child: _VerifiedPip()),

                if (blurred)
                  const Center(child: _LockPip())
                else
                Positioned(
                  left: 9,
                  right: 8,
                  bottom: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      if (distanceBand != null && distanceBand!.isNotEmpty)
                        Text(
                          isOnline ? '$distanceBand · online' : distanceBand!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFF3BD07E),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.85),
            width: 2,
          ),
        ),
      );
}

/// Marks a card the viewer has not unlocked.
class _LockPip extends StatelessWidget {
  const _LockPip();

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_outline,
          size: 15,
          color: AppColors.white,
        ),
      );
}

class _VerifiedPip extends StatelessWidget {
  const _VerifiedPip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Icon(Icons.check, size: 10, color: AppColors.primary),
      );
}
