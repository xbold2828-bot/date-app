import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_format.dart';
import '../../../data/models/match_model.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/heart_shape.dart';
import '../../common/widgets/widgets.dart';
import '../providers/match_provider/match_provider.dart';
import '../screens/chat_detail_screen.dart';

/// My cover photo, for my half of the celebration. Null until both the
/// account and the gallery have loaded — the card falls back to a monogram.
final myCoverPhotoProvider = Provider.autoDispose<String?>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  final id = me?.primaryPhotoId;
  if (id == null) return null;
  final media = ref.watch(myMediaProvider).valueOrNull ?? const [];
  for (final asset in media) {
    if (asset.id == id) return asset.url;
  }
  return null;
});

/// Hosts the match celebration above whatever screen is open.
///
/// Mounted once, high in the tree, because a match can arrive from two very
/// different places: the response to a like the person just tapped, and the
/// socket telling them somebody else completed one. Only the first has a screen
/// that could reasonably own the animation, so neither does.
class MatchCelebrationHost extends ConsumerWidget {
  const MatchCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebration = ref.watch(matchCelebrationProvider);

    // Only asked for while there is a match on screen, so an ordinary session
    // never fetches the gallery just to have it ready.
    final myPhoto = celebration == null
        ? null
        : ref.watch(myCoverPhotoProvider);
    final myName = celebration == null
        ? null
        : ref.watch(meProvider).valueOrNull?.displayName;

    return Stack(
      children: [
        child,
        if (celebration != null)
          MatchCelebrationOverlay(
            key: ValueKey(celebration.user.id),
            user: celebration.user,
            conversationId: celebration.conversationId,
            myPhotoUrl: myPhoto,
            myName: myName,
            onDismiss: () =>
                ref.read(matchCelebrationProvider.notifier).dismiss(),
          ),
      ],
    );
  }
}

/// "It's mutual." — the one moment in the app worth interrupting somebody for.
///
/// Two photo cards swing in from opposite edges and land overlapping, like two
/// tickets on a bar; a hand-stamp comes down where they cross — the stamp you
/// get on the way into a club, the night's proof that you're in. The thud is
/// felt as well as seen.
///
/// It plays once and is dismissible from anywhere, including the backdrop —
/// a celebration that traps you stops being one. With reduced motion the whole
/// composition simply fades in, already landed.
class MatchCelebrationOverlay extends StatefulWidget {
  const MatchCelebrationOverlay({
    super.key,
    required this.user,
    required this.onDismiss,
    this.conversationId,
    this.myPhotoUrl,
    this.myName,
  });

  final LikeCard user;
  final String? conversationId;
  final VoidCallback onDismiss;
  final String? myPhotoUrl;
  final String? myName;

  @override
  State<MatchCelebrationOverlay> createState() =>
      _MatchCelebrationOverlayState();
}

class _MatchCelebrationOverlayState extends State<MatchCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// The backdrop's own fade — quick, so the dim arrives before the cards do.
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// When the stamp meets the cards, as a fraction of [_enter].
  static const double _impact = 0.6;

  bool _thudPlayed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _backdrop.forward();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Already landed; only the backdrop fade runs.
      _enter.value = 1;
      _thudPlayed = true;
    } else {
      _enter
        ..addListener(_maybeThud)
        ..forward();
    }
  }

  void _maybeThud() {
    if (_thudPlayed || _enter.value < _impact) return;
    _thudPlayed = true;
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _enter.removeListener(_maybeThud);
    _enter.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  String get _name => widget.user.displayName ?? 'Someone';

  void _openChat({String? draft}) {
    widget.onDismiss();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: widget.conversationId,
          userId: widget.user.id,
          userName: _name,
          userAge: widget.user.age,
          photoUrl: widget.user.primaryPhotoUrl,
          initialDraft: draft,
        ),
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────

  double _span(double from, double to, [Curve curve = Curves.linear]) {
    final t = ((_enter.value - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  static const _easeOut = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final distance = formatDistanceAway(widget.user.distanceMeters);
    final sub = distance == null
        ? 'You and $_name both said yes.'
        : distance == 'Right here'
        ? 'You and $_name both said yes — and they\'re right here.'
        // The distance on its own line; run on, it broke with "away."
        // stranded beneath.
        : 'You and $_name both said yes.\n$_name is $distance.';

    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: "It's mutual. You and $_name liked each other.",
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _backdrop, curve: Curves.easeOut),
          child: Material(
            color: const Color(0xFF0B0B14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Backdrop(photoUrl: widget.user.primaryPhotoUrl),
                // Tap anywhere to leave. The buttons are the intent; this is
                // the escape.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                          child: AnimatedBuilder(
                            animation: _enter,
                            builder: (context, _) => _content(
                              constraints.maxWidth,
                              constraints.maxHeight,
                              sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(double width, double height, String sub) {
    final headline = _span(0.58, 0.84, _easeOut);
    final details = _span(0.66, 0.9, _easeOut);
    final actions = _span(0.72, 1.0, _easeOut);

    // On a short phone the whole moment — and both ways out — has to fit
    // without scrolling, so the cards and the gaps give before the type does.
    final compact = height < 700;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _cards(width, height, compact),
        SizedBox(height: compact ? 20 : 34),
        _rise(
          headline,
          Text(
            "It's mutual.",
            textAlign: TextAlign.center,
            style: AppTextStyles.question.copyWith(
              fontSize: 40,
              color: AppColors.onImage,
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        _rise(
          details,
          Text(
            sub,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 15.5,
              color: AppColors.onImage.withValues(alpha: 0.8),
            ),
          ),
        ),
        SizedBox(height: compact ? 14 : 22),
        _rise(
          details,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opener in _openers)
                _OpenerChip(
                  label: opener,
                  onTap: () => _openChat(draft: opener),
                ),
            ],
          ),
        ),
        SizedBox(height: compact ? 16 : 26),
        _rise(
          actions,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              children: [
                _WhiteButton(label: 'Send a message', onTap: _openChat),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: widget.onDismiss,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(
                    'Keep browsing',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.onImage.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _openers {
    final first = _name.split(' ').first;
    return [
      'Out tonight?',
      'Where are you headed?',
      if (first.isNotEmpty && first != 'Someone') 'Hey $first',
    ];
  }

  Widget _rise(double t, Widget child) => Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
  );

  /// Two tickets swinging in and landing crossed, then the stamp.
  Widget _cards(double width, double height, bool compact) {
    final cardW = math.min(
      math.min(width * 0.38, 168.0),
      height * (compact ? 0.2 : 0.24),
    );
    final cardH = cardW * 1.32;
    final overlap = cardW * 0.2;
    final rest = cardW / 2 - overlap / 2;

    // Cards: in from beyond the edges, over-rotated, settling at ±8°.
    final left = _span(0.0, 0.46, Curves.easeOutBack);
    final right = _span(0.06, 0.52, Curves.easeOutBack);
    final travel = width * 0.75;

    // The stamp: drops in large and fast, hits at [_impact], settles.
    final drop = _span(0.42, _impact, Curves.easeIn);
    final settle = _span(_impact, 0.72, _easeOut);
    final stampScale = _enter.value < _impact
        ? 1.9 -
              0.98 *
                  drop // 1.9 → 0.92, a slight squash on contact
        : 0.92 + 0.08 * settle;
    final stampOpacity = _span(0.42, 0.5);

    // The jolt the cards take when the stamp lands.
    final joltT = _span(_impact, 0.74);
    final jolt = math.sin(joltT * math.pi) * 5;

    // Ink spreading out from the impact.
    final ink = _span(_impact, 0.88, _easeOut);

    final stampSize = cardW * 0.62;

    return SizedBox(
      height: cardH + 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(-rest - travel * (1 - left), jolt),
            child: Transform.rotate(
              angle: _deg(-8 - 14 * (1 - left)),
              child: _PhotoCard(
                width: cardW,
                height: cardH,
                photoUrl: widget.myPhotoUrl,
                monogram: _initial(widget.myName, fallback: 'Y'),
                colorIndex: 3,
                semanticLabel: 'You',
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(rest + travel * (1 - right), jolt),
            child: Transform.rotate(
              angle: _deg(8 + 14 * (1 - right)),
              child: _PhotoCard(
                width: cardW,
                height: cardH,
                photoUrl: widget.user.primaryPhotoUrl,
                monogram: _initial(widget.user.displayName, fallback: '?'),
                colorIndex: 0,
                verified: widget.user.isVerified,
                semanticLabel: _name,
              ),
            ),
          ),
          if (ink > 0 && ink < 1)
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(stampSize * 2.6),
                painter: _InkRingPainter(progress: ink, radius: stampSize / 2),
              ),
            ),
          Transform.translate(
            offset: Offset(0, cardH * 0.22),
            child: Opacity(
              opacity: stampOpacity,
              child: Transform.rotate(
                angle: _deg(-14 - 16 * (1 - drop)),
                child: Transform.scale(
                  scale: stampScale,
                  child: _MutualStamp(size: stampSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _deg(double d) => d * math.pi / 180;

  static String _initial(String? name, {required String fallback}) {
    final n = (name ?? '').trim();
    return n.isEmpty ? fallback : n[0].toUpperCase();
  }
}

/// Their photo, blurred into a field of colour so the moment is lit by them —
/// and darkened enough that white type holds on any photo.
class _Backdrop extends StatelessWidget {
  const _Backdrop({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0xD90B0B14)],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.width,
    required this.height,
    required this.monogram,
    required this.colorIndex,
    required this.semanticLabel,
    this.photoUrl,
    this.verified = false,
  });

  final double width;
  final double height;
  final String? photoUrl;
  final String monogram;
  final int colorIndex;
  final bool verified;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: avatarGradient(colorIndex)),
      child: Center(
        child: Text(monogram, style: AppTextStyles.avatarInitial(width * 0.36)),
      ),
    );

    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.onImage,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl == null)
                fallback
              else
                Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : fallback,
                ),
              if (verified)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: VerificationTick(size: 20, semanticLabel: null),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The door stamp: a blue disc, a heart, and the words running round the rim.
class _MutualStamp extends StatelessWidget {
  const _MutualStamp({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StampPainter(
          ink: AppColors.isDark ? const Color(0xFF4A7FE8) : AppColors.primary,
          text: "IT'S MUTUAL  •  COZUNE  •  ",
          textStyle: AppTextStyles.caption.copyWith(
            fontSize: size * 0.105,
            color: AppColors.onImage,
            fontWeight: FontWeight.w800,
            fontVariations: const [FontVariation('wght', 800)],
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({
    required this.ink,
    required this.text,
    required this.textStyle,
  });

  final Color ink;
  final String text;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(
      c.translate(0, r * 0.08),
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, r, Paint()..color = ink);

    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      c,
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.035)
        ..color = const Color(0xCCFFFFFF),
    );

    final heart = r * 0.62;
    canvas.drawPath(
      heartPath(
        Rect.fromCenter(
          center: c.translate(0, r * 0.03),
          width: heart,
          height: heart,
        ),
      ),
      white,
    );

    _drawRimText(canvas, c, r * 0.85);
  }

  /// Lays [text] around a circle of [radius], reading clockwise from the top,
  /// spaced so it closes on itself.
  void _drawRimText(Canvas canvas, Offset c, double radius) {
    final glyphs = [
      for (final ch in text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    if (glyphs.isEmpty) return;
    final total = glyphs.fold<double>(0, (sum, g) => sum + g.width);
    final gap = math.max(0.0, (2 * math.pi * radius - total) / glyphs.length);

    var angle = -math.pi / 2;
    for (final g in glyphs) {
      final mid = angle + (g.width / 2) / radius;
      canvas.save();
      canvas.translate(
        c.dx + radius * math.cos(mid),
        c.dy + radius * math.sin(mid),
      );
      canvas.rotate(mid + math.pi / 2);
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      angle += (g.width + gap) / radius;
    }
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.ink != ink || old.text != text || old.textStyle != textStyle;
}

/// The ring of ink that spreads from the stamp as it lands.
class _InkRingPainter extends CustomPainter {
  const _InkRingPainter({required this.progress, required this.radius});

  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      radius * (1 + 1.1 * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - progress) + 0.5
        ..color = AppColors.onImage.withValues(alpha: 0.5 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_InkRingPainter old) =>
      old.progress != progress || old.radius != radius;
}

class _OpenerChip extends StatelessWidget {
  const _OpenerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start with: $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.onImage.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.onImage.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              label,
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 14,
                color: AppColors.onImage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The primary action on a dark, photographic ground: white with ink text,
/// which holds whatever colour the blurred photo behind it turns out to be.
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.onImage,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(
                color: const Color(0xFF141428),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
