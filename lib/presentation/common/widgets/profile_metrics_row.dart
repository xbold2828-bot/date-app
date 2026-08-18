import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// The three numbers a profile carries: how many people opened it, how many
/// liked it, and how many conversations came out of that.
///
/// Each one is nullable, and null renders as an em dash rather than as zero.
/// "Nobody has visited you" and "we could not load your visits" are different
/// statements, and a profile that quietly claims the first when it means the
/// second is worse than one that admits it does not know.
class ProfileMetricsRow extends StatelessWidget {
  const ProfileMetricsRow({
    super.key,
    required this.visits,
    required this.likes,
    required this.friends,
    this.compact = false,
    this.omitUnknown = false,
  });

  /// Profile visits, counted server-side (one per viewer per day).
  final int? visits;

  /// Likes received, all time.
  final int? likes;

  /// Active conversations — computed on this device from the chat list, never
  /// fetched as a number.
  final int? friends;

  /// Tighter type and padding, for the profile sheet where this sits under a
  /// photo rather than in a card of its own.
  final bool compact;

  /// Drop a tile entirely rather than dashing it.
  ///
  /// For the *other* person's profile, where "friends" is not merely missing
  /// but unknowable: it is counted from the viewer's own inbox, and nobody can
  /// count somebody else's conversations. A permanent dash there would read as
  /// a number that failed to load, so the tile is left out instead.
  final bool omitUnknown;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (!(omitUnknown && visits == null))
        _Metric(
          value: visits,
          label: 'Visits',
          icon: Icons.visibility_outlined,
          compact: compact,
        ),
      if (!(omitUnknown && likes == null))
        _Metric(
          value: likes,
          label: 'Likes',
          icon: Icons.favorite_border,
          compact: compact,
        ),
      if (!(omitUnknown && friends == null))
        _Metric(
          value: friends,
          label: 'Friends',
          icon: Icons.chat_bubble_outline,
          compact: compact,
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) _Divider(compact: compact),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.compact,
  });

  final int? value;
  final String label;
  final IconData icon;
  final bool compact;

  /// 1 200 people is a crowd; "1.2k" is a number. Past a thousand the exact
  /// figure stops being information and starts being noise in a 100 px column.
  static String format(int value) {
    if (value < 1000) return '$value';
    if (value < 100000) {
      final thousands = value / 1000;
      // 1.2k up to 99.9k, dropping a trailing ".0".
      final text = thousands.toStringAsFixed(thousands < 10 ? 1 : 0);
      return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}k';
    }
    return '${(value / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    final count = value;

    return Expanded(
      child: Semantics(
        label: count == null
            ? '$label unavailable'
            : '$count ${label.toLowerCase()}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 15 : 17,
              color: AppColors.iconMuted,
            ),
            SizedBox(height: compact ? 5 : 7),
            Text(
              count == null ? '—' : format(count),
              maxLines: 1,
              style: AppTextStyles.title.copyWith(
                fontSize: compact ? 18 : 21,
                color: count == null ? AppColors.textGrey : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              style: AppTextStyles.caption.copyWith(
                fontSize: compact ? 9.5 : 10,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: compact ? 34 : 40,
        color: AppColors.inputBorder,
      );
}
