import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ads/rewarded/rewarded_ad_provider.dart';
import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../common/widgets/widgets.dart';
import '../models/like_quota_model.dart';
import '../providers/like_quota_provider/like_quota_provider.dart';
import 'heart_shape.dart';

const Cubic _easeOut = Cubic(0.23, 1, 0.32, 1);

/// Most hearts drawn in the sheet. Anything above this is shown as "+N".
const int _maxHearts = 10;

/// Colour of the like heart, on the dashboard meter and in the sheet.
Color get _likeRed => AppColors.danger;

/// How many likes are left today, as a heart that empties as you spend them.
///
/// The number is the exact count; the fill level is what reads at a glance —
/// and it drains the moment a like lands, which is the feedback that the like
/// cost something.
class LikesMeter extends StatelessWidget {
  const LikesMeter({super.key, required this.quota, required this.onTap});

  final LikeQuota quota;
  final VoidCallback onTap;

  /// 0..1 — how full the heart is, measured against the FREE DAILY limit
  /// (not `allowance`, which grows with every ad watched and would make the
  /// heart look emptier after each ad). Ad likes beyond the daily limit read
  /// as full. An unknown limit (before the first fetch) reads as full rather
  /// than as "you have nothing".
  static double fillOf(LikeQuota q) {
    if (q.unlimited) return 1;
    if (q.dailyLimit <= 0) return q.remaining > 0 ? 1 : 0;
    return (q.remaining / q.dailyLimit).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final empty = !quota.unlimited && quota.remaining <= 0;
    final count = quota.remaining > 99 ? '99+' : '${quota.remaining}';

    return Semantics(
      button: true,
      label: quota.unlimited
          ? 'Likes today: unlimited'
          : 'Likes today: ${quota.remaining} left',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeartGauge(
                  size: 21,
                  fill: fillOf(quota),
                  color: empty ? AppColors.iconMuted : _likeRed,
                ),
                const SizedBox(width: 6),
                if (quota.unlimited)
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 17,
                    color: AppColors.textDark,
                  )
                else
                  Text(
                    count,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      height: 1.2,
                      color: empty ? AppColors.textGrey : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                      fontFeatures: const [FontFeature.tabularFigures()],
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

/// A heart outline filled from the bottom up to [fill]. Animates between
/// levels, so spending a like visibly drains it.
class HeartGauge extends StatelessWidget {
  const HeartGauge({
    super.key,
    required this.size,
    required this.fill,
    required this.color,
  });

  final double size;
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fill.clamp(0.0, 1.0)),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 520),
      curve: _easeOut,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _HeartPainter(fill: value, color: color),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({required this.fill, required this.color});

  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = heartPath(Offset.zero & size);

    if (fill > 0) {
      // The heart's ink spans roughly 0.08h–0.92h; mapping the level onto
      // that band keeps a third of a heart looking like a third.
      const top = 0.08;
      const bottom = 0.92;
      final level = size.height * (bottom - (bottom - top) * fill);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTRB(0, level, size.width, size.height),
        Paint()..color = color,
      );
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, size.width * 0.085)
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.fill != fill || old.color != color;
}

/// The day's likes, in full: what is left, when it refills, and the two ways
/// to more.
Future<void> showLikesTodaySheet(BuildContext context) {
  return showRadiusSheet<void>(
    context: context,
    builder: (_) => const _LikesTodaySheet(),
  );
}

class _LikesTodaySheet extends ConsumerStatefulWidget {
  const _LikesTodaySheet();

  @override
  ConsumerState<_LikesTodaySheet> createState() => _LikesTodaySheetState();
}

class _LikesTodaySheetState extends ConsumerState<_LikesTodaySheet> {
  /// Drives the "Loading" label. Ends the moment the ad opens.
  bool _watching = false;

  /// Blocks double taps for the whole flow: ad loading, ad playing, and the
  /// unlock request after it. Stays on after the ad opens, unlike [_watching].
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Re-read the quota whenever the sheet opens, so it is never stale.
    // refresh() shows an AppSnackBar itself if the request fails.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(likeQuotaProvider.notifier).refresh();
    });
  }

  /// Watch an ad -> +likes. The user can repeat this as many times as the
  /// server allows (`canEarnMore`); the button stays visible until then.
  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _watching = true;
    });
    try {
      final earned = await ref
          .read(rewardedAdControllerProvider.notifier)
          .showAdToUnlock(
        RewardedUnlockType.getMoreLikes,
        // The ad is on screen now — stop showing "Loading".
        onAdShown: () {
          if (mounted) setState(() => _watching = false);
        },
      );
      if (!mounted) return;
      if (!earned) {
        AppSnackBar.showWarningSnackBar(
          message: 'Watch the whole ad to get the like.',
        );
        return;
      }

      // unlockMore sends the idempotencyKey and writes the fresh quota into
      // state from the response, so no extra refresh() call is needed.
      // If it fails it shows the error snackbar itself and returns false —
      // we stop right here and hit no other API.
      final ok = await ref.read(likeQuotaProvider.notifier).unlockMore();
      if (!ok) return;

      AppSnackBar.showSuccessSnackBar(message: 'Like added');
    } on AppException catch (e) {
      AppSnackBar.showErrorSnackBar(message: e.message);
    } catch (_) {
      AppSnackBar.showErrorSnackBar(
        message: 'Ad not available right now. Try again shortly.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _watching = false;
          _busy = false;
        });
      }
    }
  }

  String? _resetLabel(LikeQuota q) {
    final at = q.resetsAt;
    if (at == null) return null;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(at.toLocal());
    return 'Refills at $time';
  }

  /// Always the plain count of likes left — never a fraction, because the
  /// "total" moves every time an ad is watched.
  String _headline(LikeQuota q) {
    if (q.remaining == 0) return "You've used today's likes.";
    return '${q.remaining} ${q.remaining == 1 ? 'like' : 'likes'} left';
  }

  /// Where today's likes came from, e.g. "3 daily + 4 from ads · 6 used".
  String? _breakdown(LikeQuota q) {
    if (q.bonusFromAds <= 0) return null;
    return '${q.dailyLimit} daily + ${q.bonusFromAds} from ads · ${q.used} used';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(likeQuotaProvider);
    final q = async.valueOrNull ?? LikeQuota.empty;
    final reset = _resetLabel(q);
    final breakdown = _breakdown(q);

    return RadiusSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Text(
            'Likes today',
            style: AppTextStyles.title.copyWith(fontSize: 23),
          ),
          const SizedBox(height: 18),
          if (q.unlimited)
            Row(
              children: [
                HeartGauge(size: 30, fill: 1, color: _likeRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unlimited — Premium covers every like.',
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15.5),
                  ),
                ),
              ],
            )
          else ...[
            _HeartRow(remaining: q.remaining, dailyLimit: q.dailyLimit),
            const SizedBox(height: 14),
            Text(
              _headline(q),
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (breakdown != null) ...[
              const SizedBox(height: 2),
              Text(breakdown, style: AppTextStyles.bodyMuted),
            ],
            if (reset != null) ...[
              const SizedBox(height: 2),
              Text(reset, style: AppTextStyles.bodyMuted),
            ],
            const SizedBox(height: 22),
            if (q.canEarnMore) ...[
              RadiusButton(
                label: _watching
                    ? 'Loading'
                    : q.likesPerAd > 1
                    ? 'Watch a short ad for +${q.likesPerAd} likes'
                    : 'Watch a short ad for +1 like',
                isLoading: _watching,
                onPressed: _watchAd,
              ),
              const SizedBox(height: 10),
            ],
            RadiusButton(
              label: 'Unlimited likes with Premium',
              kind: RadiusButtonKind.premium,
              onPressed: () {
                Navigator.pop(context);
                context.push(AppRoutes.buyPremium);
              },
            ),
            if (!q.canEarnMore && q.maxPerDay > 0) ...[
              const SizedBox(height: 12),
              Text(
                "You've reached today's ${q.maxPerDay}-like ceiling.",
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(
              'Not now',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One heart per like left, on a base row of [dailyLimit] hearts: the daily
/// ones show outlined once spent, and ad likes add full hearts on top. Spent
/// ad likes do NOT leave empty hearts behind, so watching an ad never makes
/// the row look emptier. Capped at [_maxHearts]; anything beyond reads "+N".
class _HeartRow extends StatelessWidget {
  const _HeartRow({required this.remaining, required this.dailyLimit});

  final int remaining;
  final int dailyLimit;

  @override
  Widget build(BuildContext context) {
    // Never fewer hearts than likes left, so ad likes are not hidden.
    final total = math.max(dailyLimit, remaining).clamp(1, _maxHearts);
    final overflow = remaining > _maxHearts ? remaining - _maxHearts : 0;

    return Semantics(
      label: '$remaining likes left',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            HeartGauge(
              size: 30,
              fill: i < remaining ? 1 : 0,
              color: i < remaining ? _likeRed : AppColors.iconMuted,
            ),
          if (overflow > 0)
            Text(
              '+$overflow',
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                color: _likeRed,
              ),
            ),
        ],
      ),
    );
  }
}