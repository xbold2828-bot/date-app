import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/location_sharing_model.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/location_sharing_provider.dart';
import '../../common/widgets/widgets.dart';
import './location_audience_screen.dart';

/// Who can see me on the Explore map.
///
/// ## One radio group, always telling the truth
///
/// The four options and the switch at the top are the same setting, not two.
/// Turning the switch off ticks "No one"; ticking "No one" turns the switch
/// off. There is no state where the header says one thing and the list below
/// says another, because both read the same field — which is the whole reason
/// the server models "off" as a flag over a preserved audience rather than as
/// a fourth audience that would overwrite the choice underneath it.
///
/// The list is never dimmed or disabled while sharing is off. A greyed-out
/// group would be truthful about the current state and useless for changing
/// it: turning sharing back on is exactly what somebody on this screen is
/// trying to do, and it should take one tap on the audience they want, not two
/// on two different controls.
class LocationSharingScreen extends ConsumerStatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  ConsumerState<LocationSharingScreen> createState() =>
      _LocationSharingScreenState();
}

class _LocationSharingScreenState extends ConsumerState<LocationSharingScreen> {
  @override
  void initState() {
    super.initState();
    // Confirm against the server rather than trusting the cached self-view
    // this was seeded from. Quiet, and quietly ignored if it fails — see
    // `LocationSharingNotifier.reload`.
    Future.microtask(() => ref.read(locationSharingProvider.notifier).reload());
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(locationSharingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Location sharing',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => _ErrorState(
            onRetry: () => ref.invalidate(locationSharingProvider),
          ),
          data: (sharing) => _Body(sharing: sharing),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.sharing});

  final LocationSharing sharing;

  /// Every write goes through here so a refused one is reported once, in one
  /// voice. The notifier has already put the old value back by the time this
  /// runs — see `LocationSharingNotifier._write`.
  Future<void> _apply(
    BuildContext context,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } on AppException catch (e) {
      if (context.mounted) {
        showRadiusToast(context, e.message, tone: ToastTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(locationSharingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _MasterToggle(
          enabled: sharing.enabled,
          onChanged: (value) =>
              _apply(context, () => notifier.setEnabled(value)),
        ),
        const SizedBox(height: 24),

        Text('WHO CAN SEE MY LOCATION', style: AppTextStyles.label),
        const SizedBox(height: 10),

        RadiusOptionTile(
          title: 'Everyone',
          subtitle: 'Anyone who has messaged you, replied or not',
          selected: sharing.enabled &&
              sharing.audience == LocationAudience.everyone,
          onTap: () => _apply(
            context,
            () => notifier.setAudience(LocationAudience.everyone),
          ),
        ),
        const SizedBox(height: 10),

        RadiusOptionTile(
          title: 'All friends',
          subtitle: "Everyone you're vibing with",
          selected:
              sharing.enabled && sharing.audience == LocationAudience.friends,
          onTap: () => _apply(
            context,
            () => notifier.setAudience(LocationAudience.friends),
          ),
        ),
        const SizedBox(height: 10),

        RadiusOptionTile(
          title: 'Selected friends',
          subtitle: 'Only the people you pick',
          selected:
              sharing.enabled && sharing.audience == LocationAudience.selected,
          onTap: () => _openPicker(context, ref),
        ),

        // The chosen people, folded under the tile they belong to. Shown only
        // once that tile is live: a list of names under an unselected option
        // reads as though it were in force.
        if (sharing.enabled && sharing.audience == LocationAudience.selected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _SelectedFriends(
              allowedUserIds: sharing.allowedUserIds,
              onManage: () => _openPicker(context, ref),
            ),
          ),
        const SizedBox(height: 10),

        RadiusOptionTile(
          title: 'No one',
          subtitle: 'Turn off location sharing',
          selected: !sharing.enabled,
          onTap: () => _apply(context, () => notifier.setEnabled(false)),
        ),

        const SizedBox(height: 20),
        _StateLine(sharing: sharing),
        const SizedBox(height: 12),

        // The honest bit. A privacy screen that let "no one" imply an
        // invisibility the product does not deliver would be worse than no
        // screen at all.
        const NoticeBox(
          icon: Icons.shield_outlined,
          text: 'Your pin is never your exact spot — people see a rough area '
              'a few hundred metres across, and never an address. This '
              'controls the map only: Radar still tells people nearby roughly '
              'how far away you are, which is how Radius finds anyone at all.',
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final chosen = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationAudienceScreen(
          initialSelection: sharing.allowedUserIds,
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    await _apply(
      context,
      () => ref
          .read(locationSharingProvider.notifier)
          .setAllowedFriends(chosen),
    );
  }
}

/// The switch, and the one-line summary of what it currently means.
class _MasterToggle extends StatelessWidget {
  const _MasterToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadiusCard(
      tinted: enabled,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.near_me : Icons.near_me_disabled_outlined,
              size: 20,
              color: enabled ? AppColors.onAccent : AppColors.iconMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Share live location',
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'On — people you choose can see you'
                      : 'Off — nobody can see you on the map',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Share live location',
            toggled: enabled,
            child: Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.onAccent,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: AppColors.background,
              inactiveTrackColor: AppColors.inputBorder,
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.inputBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faces of the people currently named, and the way back into the picker.
class _SelectedFriends extends ConsumerWidget {
  const _SelectedFriends({required this.allowedUserIds, required this.onManage});

  final List<String> allowedUserIds;
  final VoidCallback onManage;

  /// How many faces fit before the row starts crowding the count beside it.
  static const int _maxFaces = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(sharingFriendsProvider).valueOrNull ?? const [];
    final chosen = [
      for (final friend in friends)
        if (allowedUserIds.contains(friend.id)) friend,
    ];

    // Nobody picked yet — the state the screen is in the moment somebody taps
    // "Selected friends" for the first time. It says what to do, because the
    // setting is doing nothing until they do it.
    if (allowedUserIds.isEmpty) {
      return _ManageRow(
        onManage: onManage,
        actionLabel: 'Choose',
        child: Text(
          'No one picked yet — nobody can see you',
          style: AppTextStyles.caption.copyWith(color: AppColors.primaryInk),
        ),
      );
    }

    return _ManageRow(
      onManage: onManage,
      actionLabel: 'Manage',
      child: Row(
        children: [
          if (chosen.isNotEmpty)
            SizedBox(
              // Overlapped faces: each one after the first adds only its
              // visible sliver.
              width: 30 + (chosen.take(_maxFaces).length - 1) * 20.0,
              height: 30,
              child: Stack(
                children: [
                  for (final (index, friend)
                      in chosen.take(_maxFaces).indexed)
                    Positioned(
                      left: index * 20.0,
                      child: _Face(friend: friend, colorIndex: index),
                    ),
                ],
              ),
            ),
          if (chosen.isNotEmpty) const SizedBox(width: 10),
          Expanded(
            child: Text(
              _countLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _countLabel {
    final n = allowedUserIds.length;
    return n == 1 ? '1 friend can see you' : '$n friends can see you';
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.child,
    required this.onManage,
    required this.actionLabel,
  });

  final Widget child;
  final VoidCallback onManage;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primarySoft, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.friend, required this.colorIndex});

  final ChatOtherUser friend;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final name = friend.displayName ?? 'Someone';
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryTint, width: 2),
        gradient:
            friend.primaryPhotoUrl == null ? avatarGradient(colorIndex) : null,
        image: friend.primaryPhotoUrl != null
            ? DecorationImage(
                image: NetworkImage(friend.primaryPhotoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: friend.primaryPhotoUrl == null
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.avatarInitial(12),
              ),
            )
          : null,
    );
  }
}

/// What is true right now, in one sentence, at the bottom of the choices.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.sharing});

  final LocationSharing sharing;

  @override
  Widget build(BuildContext context) {
    final sharingWithSomeone = sharing.isSharingWithAnyone;
    final text = switch (sharing) {
      LocationSharing(enabled: false) =>
        'Location sharing is off. You are not on anyone\'s map.',
      LocationSharing(audience: LocationAudience.everyone) =>
        'Anyone you have a conversation with can see you on the map.',
      LocationSharing(audience: LocationAudience.friends) =>
        'The people you are vibing with can see you on the map.',
      LocationSharing(allowedUserIds: []) =>
        'No friends picked yet, so nobody can see you on the map.',
      _ => 'Only the friends you picked can see you on the map.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          sharingWithSomeone
              ? Icons.check_circle_outline
              : Icons.visibility_off_outlined,
          size: 16,
          color: sharingWithSomeone ? AppColors.ok : AppColors.iconMuted,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.caption)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
      child: Column(
        children: [
          RadarMark(size: 84, color: AppColors.iconMuted),
          const SizedBox(height: 20),
          Text(
            "Couldn't load your setting",
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing has changed — whoever could see you before still can.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          RadiusButton(
            label: 'Try again',
            onPressed: onRetry,
            kind: RadiusButtonKind.ghost,
            expand: false,
          ),
        ],
      ),
    );
  }
}
