import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/map_user_model.dart';
import 'explore_avatar.dart';

/// The row of faces above the map.
///
/// Layout: a pinned "All" tile on the left, a thin divider, then the scrolling
/// row of people. The strip has no container of its own: it sits directly on
/// the header, so there is no card inside a card.
///
/// "All" is always in the same spot, so the way back to everybody never moves.
/// When somebody is selected they jump to the front of the scrolling row.
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

  /// Opens the grid of everybody. Both the pinned "All" tile and the trailing
  /// "See all" tile go here.
  final VoidCallback onShowAll;

  /// Past this many people, a "See all" tile is offered at the end of the row.
  static const int gridThreshold = 8;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    // Nothing to pick from: the empty-state card on the map explains why.
    if (people.isEmpty) return const SizedBox.shrink();

    // Selected first, then everyone else in API order (nearest first), so the
    // row does not reshuffle on every selection.
    final ordered = <MapUser>[
      ...people.where((person) => person.id == selectedId),
      ...people.where((person) => person.id != selectedId),
    ];
    final hasSeeAll = people.length > gridThreshold;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          _AllTile(active: selectedId == null, onTap: onShowAll),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.inputBorder,
          ),
          Expanded(
            child: ShaderMask(
              // Soft fade on the right edge hints that the row scrolls.
              shaderCallback: (rect) => const LinearGradient(
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.92, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: ordered.length + (hasSeeAll ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
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
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExploreAvatar(
                name: person.displayName,
                photoUrl: person.primaryPhotoUrl,
                size: 48,
                selected: selected,
                isOnline: person.isOnline,
              ),
              const SizedBox(height: 4),
              Text(
                person.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
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

/// A round tile with an icon and a caption, matching a person's silhouette so
/// the row reads as one rhythm rather than controls bolted onto faces.
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
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
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
                  size: 22,
                  color: active ? AppColors.onImage : AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
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
    label: 'All',
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
    label: 'See all',
    active: false,
    onTap: onTap,
    semanticLabel: 'See all $count people in a grid',
  );
}