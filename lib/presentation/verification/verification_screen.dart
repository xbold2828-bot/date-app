import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_string.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/media_model.dart';
import '../../data/models/verification_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/profile_provider.dart';
import '../common/widgets/widgets.dart';
import 'face_camera.dart';
import 'face_challenge.dart';

/// The live face check, start to finish.
///
/// Intro → the camera challenge (ML Kit on the phone) → upload the four
/// stills → the server's decision. Every network step can be retried without
/// filming again; only a rejection starts over.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

enum _Phase {
  loading,
  intro,
  preparing,
  capturing,
  checking,
  verified,
  rejected,
  photosBlocking,
  failed,
}

class _VerificationScreenState extends ConsumerState<VerificationScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  VerificationStatus? _status;

  VerificationStart? _session;
  FaceChallenge? _challenge;
  FaceCamera? _camera;
  final Map<FramePose, Uint8List> _photos = {};

  /// When a face was last in view — "no face" for a few seconds means "dark".
  DateTime _lastFace = DateTime.now();
  bool _finishing = false;

  // Outcome.
  String? _message;
  bool _stillVerified = false;
  List<BlockingPhoto> _blocking = const [];
  bool _removing = false;

  /// What "Try again" repeats after a failure: the whole check, or only the
  /// upload and decision when the photos are already taken.
  Future<void> Function()? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_closeCamera());
    super.dispose();
  }

  /// The camera is not ours in the background: release it, and start over
  /// from the intro when the person comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final mid = _phase == _Phase.preparing || _phase == _Phase.capturing;
    if (state == AppLifecycleState.inactive && mid) {
      unawaited(_closeCamera());
      setState(() => _phase = _Phase.intro);
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ref.read(verificationRepositoryProvider).status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Unknown is not "unavailable": let Start try, and say why if it fails.
    }
    if (mounted) setState(() => _phase = _Phase.intro);
  }

  // ── The check ──────────────────────────────────────────────────────────────

  Future<void> _begin() async {
    setState(() {
      _phase = _Phase.preparing;
      _photos.clear();
      _finishing = false;
      _message = null;
    });

    try {
      final (session, camera) = await (
        ref.read(verificationRepositoryProvider).start(),
        FaceCamera.open(),
      ).wait;
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _session = session;
      _challenge = FaceChallenge(session.challenge);
      _camera = camera;
      _lastFace = DateTime.now();
      setState(() => _phase = _Phase.capturing);
      await camera.start(_onSample);
    } on ParallelWaitError<
      (VerificationStart?, FaceCamera?),
      (AsyncError?, AsyncError?)
    > catch (e) {
      // One half may have worked; a camera that opened must not stay open.
      await e.values.$2?.dispose();
      // The camera's reason first: "allow camera access" is the one the
      // person can act on.
      _fail((e.errors.$2 ?? e.errors.$1)?.error ?? e, retry: _begin);
    } catch (e) {
      _fail(e, retry: _begin);
    }
  }

  void _onSample(FaceSample sample) {
    final challenge = _challenge;
    if (!mounted || challenge == null || _phase != _Phase.capturing) return;

    final before = (challenge.completed, challenge.hint);
    final pose = challenge.onSample(sample);
    if (sample.faceCount > 0) _lastFace = DateTime.now();
    if (challenge.completed != before.$1) HapticFeedback.selectionClick();

    if (pose != null) {
      unawaited(_take(pose));
    } else if (challenge.isDone) {
      unawaited(_finishCapture());
    }
    if ((challenge.completed, challenge.hint) != before || pose != null) {
      setState(() {});
    }
  }

  Future<void> _take(FramePose pose) async {
    final camera = _camera;
    final challenge = _challenge;
    if (camera == null || challenge == null) return;
    try {
      final (bytes, still) = await camera.takeStill();
      if (!mounted || _camera != camera) return;
      if (challenge.acceptStill(pose, still)) {
        _photos[pose] = bytes;
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      challenge.captureFailed();
    }
    if (!mounted) return;
    setState(() {});
    if (challenge.isDone) await _finishCapture();
  }

  Future<void> _finishCapture() async {
    if (_finishing) return;
    _finishing = true;
    await _closeCamera();
    await _uploadAndSubmit();
  }

  Future<void> _uploadAndSubmit() async {
    final session = _session;
    if (session == null || !mounted) return;
    setState(() => _phase = _Phase.checking);

    final repo = ref.read(verificationRepositoryProvider);
    try {
      await Future.wait([
        for (final slot in session.uploads)
          if (_photos[slot.pose] case final photo?) repo.upload(slot, photo),
      ]);
    } catch (_) {
      _fail(AppString.verifyUploadFailed, retry: _uploadAndSubmit);
      return;
    }
    await _submit();
  }

  /// The server decides here. A timed-out request or a "still checking" 409
  /// means the first attempt is still running: wait and ask again — the
  /// server answers a decided check without running it twice.
  Future<void> _submit() async {
    final session = _session;
    if (session == null || !mounted) return;
    setState(() => _phase = _Phase.checking);

    final repo = ref.read(verificationRepositoryProvider);
    VerificationResult? result;
    for (var attempt = 0; result == null; attempt++) {
      try {
        result = await repo.submit(session.sessionId);
      } on AppException catch (e) {
        final stillRunning =
            e is ConflictException || e is RequestTimeoutException;
        if (!stillRunning || attempt >= 3) {
          _fail(e, retry: _submit);
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
      }
    }

    if (!mounted) return;
    switch (result.outcome) {
      case VerificationOutcome.verified:
        HapticFeedback.heavyImpact();
        unawaited(ref.read(meProvider.notifier).refresh());
        setState(() => _phase = _Phase.verified);
      case VerificationOutcome.photosBlocking:
        ref.invalidate(myMediaProvider);
        setState(() {
          _blocking = result!.blockingPhotos;
          _message = result.message;
          _phase = _Phase.photosBlocking;
        });
      case VerificationOutcome.rejected:
        HapticFeedback.mediumImpact();
        setState(() {
          _message = result!.message;
          _stillVerified = result.verified;
          _phase = _Phase.rejected;
        });
    }
  }

  /// Delete the photos that aren't the person, then ask again — only the
  /// photos are re-checked, so there is nothing to film.
  Future<void> _removeBlockingAndFinish() async {
    setState(() => _removing = true);
    final media = ref.read(mediaRepositoryProvider);
    try {
      for (final photo in _blocking) {
        try {
          await media.delete(photo.mediaId);
        } on NotFoundException {
          // Already gone.
        }
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _removing = false);
        showRadiusToast(context, e.message, tone: ToastTone.error);
      }
      return;
    }
    ref.invalidate(myMediaProvider);
    if (!mounted) return;
    setState(() => _removing = false);
    await _submit();
  }

  void _fail(Object error, {required Future<void> Function() retry}) {
    if (!mounted) return;
    unawaited(_closeCamera());
    setState(() {
      _message = _describe(error);
      _retry = retry;
      _phase = _Phase.failed;
    });
  }

  String _describe(Object error) => switch (error) {
    final String message => message,
    CameraException(:final code) when code.startsWith('CameraAccess') =>
      AppString.verifyCameraDenied,
    CameraException() => AppString.verifyCameraUnavailable,
    RateLimitedException() => AppString.verifyTooManyTries,
    // The server's own sentences are written for this screen.
    AppException(:final message) when message.trim().isNotEmpty => message,
    _ => AppString.verifyUnavailable,
  };

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, color: AppColors.textDark),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_phase), child: _body()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_phase) {
    _Phase.loading => const _Centered(child: _Spinner()),
    _Phase.intro => _intro(),
    _Phase.preparing || _Phase.capturing => _capture(),
    _Phase.checking => _Centered(
      child: _Message(
        leading: const _Spinner(),
        title: AppString.verifyChecking,
        body: AppString.verifyCheckingBody,
      ),
    ),
    _Phase.verified => _Centered(
      child: _Message(
        leading: const VerificationTick(size: 64, semanticLabel: null),
        title: AppString.verifyDone,
        body: AppString.verifyDoneBody,
        actions: [
          RadiusButton(
            label: AppString.verifyDoneButton,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    ),
    _Phase.rejected => _Centered(
      child: _Message(
        title: _stillVerified
            ? AppString.verifyRecheckFailed
            : AppString.verifyFailedTitle,
        body: [
          _message ?? AppString.verifyUnavailable,
          if (_stillVerified) AppString.verifyStillVerified,
        ].join('\n\n'),
        actions: _retryActions(_begin),
      ),
    ),
    _Phase.photosBlocking => _photosBlocking(),
    _Phase.failed => _Centered(
      child: _Message(
        title: AppString.verifyCouldNotFinish,
        body: _message ?? AppString.verifyUnavailable,
        actions: _retryActions(_retry ?? _begin),
      ),
    ),
  };

  List<Widget> _retryActions(Future<void> Function() retry) => [
    RadiusButton(label: AppString.verifyTryAgain, onPressed: retry),
    const SizedBox(height: 10),
    RadiusButton(
      label: AppString.verifyNotNow,
      kind: RadiusButtonKind.ghost,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  ];

  Widget _intro() {
    final verified = _status?.verified ?? ref.read(meProvider).valueOrNull?.verified ?? false;
    final available = _status?.available ?? true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (verified) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: VerificationTick(size: 40, semanticLabel: null),
          ),
          const SizedBox(height: 16),
          Text(AppString.verifyAlready, style: AppTextStyles.display),
          const SizedBox(height: 8),
          Text(
            [
              if (_status?.verifiedUntil case final until?)
                AppString.verifyValidUntil(
                  DateFormat.yMMMMd().format(until.toLocal()),
                ),
              AppString.verifyAlreadyBody,
            ].join(' '),
            style: AppTextStyles.bodyMuted,
          ),
        ] else ...[
          Text(AppString.verifyTitle, style: AppTextStyles.display),
          const SizedBox(height: 8),
          Text(AppString.verifyIntro, style: AppTextStyles.bodyMuted),
        ],
        const SizedBox(height: 28),
        _Point(
          icon: Icons.face_retouching_natural_outlined,
          text: AppString.verifyHowSteps,
        ),
         _Point(
          icon: Icons.photo_camera_front_outlined,
          text: AppString.verifyHowPhotos,
        ),
        _Point(icon: Icons.lock_outline, text: AppString.verifyHowPrivate),
        _Point(
          icon: Icons.verified_outlined,
          text: AppString.verifyHowLater,
        ),
        const SizedBox(height: 20),
        Text(AppString.verifyConsent, style: AppTextStyles.caption),
        const SizedBox(height: 20),
        RadiusButton(
          label: verified ? AppString.verifyCheckAgain : AppString.verifyStart,
          kind: verified ? RadiusButtonKind.ghost : RadiusButtonKind.primary,
          onPressed: available ? _begin : null,
        ),
        if (!available) ...[
          const SizedBox(height: 12),
          Text(
            AppString.verifyUnavailable,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _capture() {
    final challenge = _challenge;
    final step = challenge?.step;
    final dark =
        challenge?.hint == FaceHint.noFace &&
        DateTime.now().difference(_lastFace) > const Duration(seconds: 4);

    final prompt = switch (step) {
      null => AppString.verifyHintPreparing,
      ChallengeStep.straight => AppString.verifyStepStraight,
      ChallengeStep.turn => AppString.verifyStepTurn,
      ChallengeStep.turnBack => AppString.verifyStepTurnBack,
      ChallengeStep.blink => AppString.verifyStepBlink,
      ChallengeStep.smile => AppString.verifyStepSmile,
    };
    final hint = dark
        ? AppString.verifyHintDark
        : switch (challenge?.hint) {
            FaceHint.noFace => AppString.verifyHintNoFace,
            FaceHint.manyFaces => AppString.verifyHintManyFaces,
            FaceHint.moveCloser => AppString.verifyHintCloser,
            FaceHint.moveBack => AppString.verifyHintBack,
            FaceHint.lookStraight => AppString.verifyHintStraight,
            null => '',
          };

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth * 0.78, 320.0);
        return Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                prompt,
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox.square(
              dimension: size + 20,
              child: CustomPaint(
                painter: _StepRing(
                  steps: challenge?.steps.length ?? 5,
                  done: challenge?.completed ?? 0,
                  doneColor: AppColors.ok,
                  currentColor: AppColors.primary,
                  todoColor: AppColors.inputBorder,
                ),
                child: Center(
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: size,
                      child: _preview(size),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                hint,
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _preview(double size) {
    final controller = _camera?.controller;
    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: AppColors.panel,
        child: const Center(child: _Spinner()),
      );
    }
    // The preview is taller than wide in portrait; cover the circle with it.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size,
        height: size * controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _photosBlocking() {
    final media = ref.watch(myMediaProvider).valueOrNull ?? const <MediaAsset>[];
    final byId = {for (final m in media) m.id: m};

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(AppString.verifyPhotosTitle, style: AppTextStyles.display),
        const SizedBox(height: 8),
        Text(_message ?? '', style: AppTextStyles.bodyMuted),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final photo in _blocking)
              _BlockingThumb(asset: byId[photo.mediaId], photo: photo),
          ],
        ),
        const SizedBox(height: 28),
        RadiusButton(
          label: _removing
              ? AppString.verifyRemoving
              : AppString.verifyRemoveAndFinish,
          isLoading: _removing,
          onPressed: _removeBlockingAndFinish,
        ),
        const SizedBox(height: 10),
        RadiusButton(
          label: AppString.verifyNotNow,
          kind: RadiusButtonKind.ghost,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// One line of "how it works": a plain icon and a sentence.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textDark),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

/// A profile photo that has to go, with why when it can't be checked.
class _BlockingThumb extends StatelessWidget {
  const _BlockingThumb({required this.asset, required this.photo});

  final MediaAsset? asset;
  final BlockingPhoto photo;

  @override
  Widget build(BuildContext context) {
    const width = 96.0;
    final url = asset?.url;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: width,
              height: width * 1.25,
              child: url == null
                  ? ColoredBox(color: AppColors.panel)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: AppColors.panel),
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: AppColors.panel),
                    ),
            ),
          ),
          if (photo.isUnreadable) ...[
            const SizedBox(height: 4),
            Text(AppString.verifyPhotoUnreadable, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: child,
    ),
  );
}

/// A result: an optional mark, a headline, a line or two, the way on.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    this.leading,
    this.actions = const [],
  });

  final Widget? leading;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(height: 20)],
        Text(title, style: AppTextStyles.display, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(body, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        if (actions.isNotEmpty) ...[const SizedBox(height: 28), ...actions],
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
  );
}

/// The ring around the camera: one segment per step, filled as they're done.
class _StepRing extends CustomPainter {
  const _StepRing({
    required this.steps,
    required this.done,
    required this.doneColor,
    required this.currentColor,
    required this.todoColor,
  });

  final int steps;
  final int done;
  final Color doneColor;
  final Color currentColor;
  final Color todoColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    const gap = 0.06; // radians between segments
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    final sweep = 2 * math.pi / steps;
    for (var i = 0; i < steps; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = i < done
            ? doneColor
            : (i == done ? currentColor : todoColor);
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StepRing old) =>
      old.steps != steps ||
      old.done != done ||
      old.doneColor != doneColor ||
      old.currentColor != currentColor ||
      old.todoColor != todoColor;
}
