import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/map_user_model.dart';
import 'explore_avatar.dart';
import 'explore_controls.dart';
import 'package:dating_app/core/constants/app_string.dart';


/// Floating row of faces over the map. Same height, radius, fill and shadow
/// as the bottom navigation bar.
///
/// A pinned "All" tile sits on the left, then a divider, then the scrolling
/// list of people. The selected person moves to the front of the list.
class ExplorePeopleStrip extends StatelessWidget {
  const ExplorePeopleStrip({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelect,
    required this.onShowAll,
  });

  final List<MapUser> people;
  final String? selectedId;
  final ValueChanged<MapUser> onSelect;

  /// Opens the grid of everybody. Used by both the "All" and "See all" tiles.
  final VoidCallback onShowAll;

  /// Past this many people, a "See all" tile is added at the end of the row.
  static const int gridThreshold = 8;

  /// Matches the bottom navigation bar.
  static const double height = 56;
  static const double radius = 28;

  static const double _avatar = 34;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final ordered = <MapUser>[
      ...people.where((person) => person.id == selectedId),
      ...people.where((person) => person.id != selectedId),
    ];
    final hasSeeAll = people.length > gridThreshold;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: floatingBarDecoration(radius: radius),
      child: Row(
        children: [
          _AllTile(active: selectedId == null, onTap: onShowAll),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.inputBorder,
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length + (hasSeeAll ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index >= ordered.length) {
                  return Center(
                    child: _ShowAllTile(
                      count: people.length,
                      onTap: onShowAll,
                    ),
                  );
                }
                final person = ordered[index];
                return Center(
                  child: _PersonTile(
                    person: person,
                    selected: person.id == selectedId,
                    onTap: () => onSelect(person),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final MapUser person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${person.displayName}, selected. Open All to see everyone again.'
          : 'Show ${person.displayName} on the map',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExploreAvatar(
                name: person.displayName,
                photoUrl: person.primaryPhotoUrl,
                size: ExplorePeopleStrip._avatar,
                selected: selected,
                isOnline: person.isOnline,
              ),
              const SizedBox(height: 2),
              Text(
                person.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  height: 1.2,
                  color: selected ? AppColors.primary : AppColors.textGrey,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [
                    FontVariation('wght', selected ? 700 : 500),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round icon tile with a caption, sized like a person's avatar.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: ExplorePeopleStrip._avatar,
                height: ExplorePeopleStrip._avatar,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.blue : AppColors.card,
                  border: Border.all(
                    color: active ? AppColors.blue : AppColors.inputBorder,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? AppColors.onImage : AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  height: 1.2,
                  color: active ? AppColors.primary : AppColors.textGrey,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [FontVariation('wght', active ? 700 : 500)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllTile extends StatelessWidget {
  const _AllTile({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _IconTile(
    icon: Icons.groups_outlined,
    label: AppString.all,
    active: active,
    onTap: onTap,
    semanticLabel: active
        ? 'Showing everyone on the map'
        : 'Show everyone on the map again',
  );
}

class _ShowAllTile extends StatelessWidget {
  const _ShowAllTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _IconTile(
    icon: Icons.grid_view_rounded,
    label: AppString.seeAll,
    active: false,
    onTap: onTap,
    semanticLabel: 'See all $count people in a grid',
  );
}