import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../common/widgets/widgets.dart';

/// The photo strip. Swipe, or tap either edge.
///
/// Dots only appear for an actual set: a single photo with a lone dot under it
/// looks like a carousel that failed to load the rest.
///
/// There is deliberately NO close button in here. The profile sheet pins a
/// single one on top of everything, so it stays visible while the page
/// scrolls — a second one in this strip would scroll away and double up.
///
/// Presence is deliberately not here either. There used to be an "Online now"
/// pill in the top-left corner, which said the same thing as the green dot six
/// lines below it and said it over the person's face.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    super.key,
    required this.photos,
    required this.fallbackInitial,
    required this.colorIndex,
  });

  final List<String> photos;
  final String fallbackInitial;
  final int colorIndex;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant PhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The photo list can change under us (the card's single photo is replaced
    // by the full set once the profile loads). Never point past the end.
    if (_index >= widget.photos.length) {
      _index = widget.photos.isEmpty ? 0 : widget.photos.length - 1;
      if (_pages.hasClients) _pages.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget get _placeholder => _ProfilePlaceholder(
    initial: widget.fallbackInitial,
    colorIndex: widget.colorIndex,
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Half the screen on phones, but never taller than a portrait photo needs
    final height = (size.height * 0.5).clamp(240.0, size.width * 1.2);
    final count = widget.photos.length;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: count == 0
                ? _placeholder
                : PageView.builder(
              controller: _pages,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                widget.photos[i],
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder,
                loadingBuilder: (_, child, progress) =>
                progress == null ? child : _placeholder,
              ),
            ),
          ),

          // Soft fade at the top so the sheet's pinned close button stays
          // readable on bright photos.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Edge taps, for one-handed use.
          if (count > 1) ...[
            _TapZone(
              alignment: Alignment.centerLeft,
              label: 'Previous photo',
              onTap: () => _step(-1),
            ),
            _TapZone(
              alignment: Alignment.centerRight,
              label: 'Next photo',
              onTap: () => _step(1),
            ),
          ],

          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: _Dots(count: count, active: _index),
            ),
        ],
      ),
    );
  }
}

class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.alignment,
    required this.label,
    required this.onTap,
  });

  final Alignment alignment;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: const FractionallySizedBox(
            widthFactor: 0.28,
            heightFactor: 1,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: 'Photo ${active + 1} of $count',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.onImage
                      .withValues(alpha: i == active ? 1 : 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Named with a `Profile` prefix to avoid colliding with Flutter's own
/// [Placeholder] widget now that this class lives in its own file.
class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder({required this.initial, required this.colorIndex});

  final String initial;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: avatarGradient(colorIndex)),
      child: Center(
        child: Text(
          initial.isNotEmpty ? initial[0].toUpperCase() : '?',
          style: AppTextStyles.avatarInitial(76).copyWith(
            color: AppColors.onImage.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}