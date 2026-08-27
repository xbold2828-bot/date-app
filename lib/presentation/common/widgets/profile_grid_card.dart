import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/distance_format.dart';
import '../../../core/utils/last_seen_format.dart';

/// The palette that stands in for a missing photo. Cool, muted, and distinct
/// enough that two adjacent cards never look like the same person.
///
/// Fixed values rather than tokens: these stand in for a photograph, and a
/// photograph does not change colour with the theme. Every pair is dark enough
/// to carry [AppColors.onImage] on top in either mode.
const List<List<Color>> kAvatarGradients = [
  [Color(0xFF5C7FB8), Color(0xFF2F4C80)],
  [Color(0xFF7C6BB8), Color(0xFF4A3E80)],
  [Color(0xFF4E8F86), Color(0xFF26564F)],
  [Color(0xFF8B6BC4), Color(0xFF52338C)],
  [Color(0xFF5B7CC8), Color(0xFF2B4795)],
  [Color(0xFF6B77B8), Color(0xFF3B4180)],
  [Color(0xFF9B6BC4), Color(0xFF63308C)],
  [Color(0xFF4F86A8), Color(0xFF25516B)],
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
/// ## Distance
///
/// The card prints a **number** when the server sent one — "190 ft", "450 m",
/// "2.4 mi" — and falls back to the coarse band otherwise. Both paths exist
/// because both cases are real: a viewer who never finished the location step
/// has no distance to anybody, a locked card is deliberately sent without one,
/// and a server that predates the field sends the band alone.
///
/// The precision is the server's decision, not this widget's. It arrives
/// already rounded (see `roundDistanceMetres`), and rounding again in
/// [formatDistance] is presentational. Nothing here may sharpen it.
class ProfileGridCard extends StatelessWidget {
  const ProfileGridCard({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.onTap,
    this.age,
    this.distanceBand,
    this.distanceMeters,
    this.lastActiveAt,
    this.photoUrl,
    this.isOnline = false,
    this.isVerified = false,
    this.blurred = false,
  });

  final String name;
  final int? age;

  /// e.g. "2-5 km". The fallback for when [distanceMeters] is absent.
  final String? distanceBand;

  /// Metres, already rounded by the server. Preferred over [distanceBand].
  final num? distanceMeters;

  /// When they were last around. Ignored while [isOnline] — the green dot and
  /// "Online now" would be the same sentence twice.
  final DateTime? lastActiveAt;

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

  /// The number when there is one, the band when there is not.
  String? get _distance {
    final exact = formatDistance(distanceMeters);
    if (exact != null) return exact;
    final band = distanceBand;
    return band == null || band.isEmpty ? null : band;
  }

  /// "Last seen", suppressed while the presence dot is already saying it.
  String? get _lastSeen =>
      isOnline ? null : formatLastSeen(lastActiveAt, isOnline: false);

  /// "450 m · 2h ago". Either half stands on its own when the other is
  /// missing, which is the common case rather than the exotic one: a viewer
  /// with no location of their own has no distances at all, and an account
  /// that has never connected has no last-seen.
  String? get _meta {
    final parts = [?_distance, ?_lastSeen];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final semantics = blurred
        ? 'Hidden profile, unlock to see who this is'
        : [
            _title,
            if (isVerified) 'verified',
            if (isOnline) 'online now',
            if (_distance case final d?) '$d away',
            if (_lastSeen case final seen?) 'last seen $seen',
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
                              color: AppColors.onImage.withValues(alpha: 0.92),
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
                      colors: [Colors.transparent, Color(0xAE0A0A14)],
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
                          color: AppColors.onImage,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      // Distance and last-seen, one line. Presence is still
                      // only the green dot in the corner — appending "·
                      // online" here said it a second time, and it was the
                      // half that got truncated first on a narrow card, which
                      // is also why last-seen drops out entirely while
                      // somebody is online rather than competing for the room.
                      if (_meta case final meta?)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            color: AppColors.onImage.withValues(alpha: 0.85),
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

/// "Here right now", and the card's only statement of it.
///
/// Sized up from 9px: at that size, over a photo, against a white ring, it read
/// as a rendering artefact rather than a signal — and it is now the *whole*
/// signal, since the "· online" text that used to back it up is gone.
class _PresenceDot extends StatelessWidget {
  const _PresenceDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: AppColors.ok,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.onImage.withValues(alpha: 0.85),
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
          color: AppColors.onImage.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_outline,
          size: 15,
          color: AppColors.onImage,
        ),
      );
}

class _VerifiedPip extends StatelessWidget {
  const _VerifiedPip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.onImage.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(Icons.check, size: 10, color: AppColors.primary),
      );
}
