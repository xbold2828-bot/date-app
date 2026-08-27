import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/location_sharing_model.dart';
import '../../../providers/location_sharing_provider.dart';
import '../screens/location_sharing_screen.dart';

/// Who can see me, on the tab where I look at myself.
///
/// Sits directly under the header — under the live location line, which says
/// *where you are* — because the question this answers is the one that follows
/// immediately from it: who else knows. Anywhere further down and it becomes a
/// setting people find only if they go looking, which for a location control
/// is the wrong shape entirely.
///
/// It states the current audience rather than the word "Location sharing" and
/// a chevron. A privacy control that does not say what it is currently doing
/// makes people open it just to check, and some of them will be surprised by
/// what they find.
class LocationSharingCard extends ConsumerWidget {
  const LocationSharingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing =
        ref.watch(locationSharingProvider).valueOrNull ?? LocationSharing.initial;
    final on = sharing.isSharingWithAnyone;

    return Semantics(
      button: true,
      label: 'Location sharing. ${_headline(sharing)}. ${_detail(sharing)}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocationSharingScreen()),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              // Tinted while sharing, plain while not. The card is loud when
              // somebody can see you and quiet when nobody can — never the
              // other way round, which would make "off" the state that shouts.
              color: on ? AppColors.primaryTint : AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: on ? AppColors.primary : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      on ? Icons.near_me : Icons.near_me_disabled_outlined,
                      size: 19,
                      color: on ? AppColors.onAccent : AppColors.iconMuted,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LIVE LOCATION',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            color: on
                                ? AppColors.primaryInk
                                : AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _headline(sharing),
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 15,
                            color: on
                                ? AppColors.primaryInk
                                : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(_detail(sharing), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: on ? AppColors.primary : AppColors.iconMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Who can see you, in as few words as fit on one line.
  String _headline(LocationSharing sharing) {
    if (!sharing.enabled) return 'Not shared with anyone';
    return switch (sharing.audience) {
      LocationAudience.everyone => 'Shared with everyone',
      LocationAudience.friends => 'Shared with all friends',
      LocationAudience.selected => sharing.allowedUserIds.isEmpty
          // Selected-with-nobody is off in every way that matters, and saying
          // "shared with selected friends" here would be a comfortable lie in
          // the other direction.
          ? 'Not shared with anyone'
          : 'Shared with ${sharing.selectedCount} '
              '${sharing.selectedCount == 1 ? 'friend' : 'friends'}',
    };
  }

  String _detail(LocationSharing sharing) {
    if (!sharing.isSharingWithAnyone) {
      return "You're off the map. Tap to change who can see you.";
    }
    return 'Tap to choose who can see you on the map';
  }
}
