/// The live face check's choreography, with no camera in it.
///
/// The screen feeds it one [FaceSample] per analysed camera frame; it decides
/// when a step is done and when a still photo should be taken. Keeping the
/// camera and ML Kit out is what lets every rule here be tested on plain
/// numbers — the server re-checks the photos either way, so this only has to
/// be good at guiding a real person, not at catching a fake one.
library;

import '../../data/models/verification_model.dart';

export '../../data/models/verification_model.dart'
    show ChallengeAction, FramePose;

/// One thing the person is asked to do.
enum ChallengeStep {
  straight,
  turn,

  /// The second turn, which has to go the other way.
  turnBack,
  blink,
  smile;

  /// The photo this step takes. A blink takes none: it is checked live,
  /// because a still can't show one.
  FramePose? get pose => switch (this) {
    straight => FramePose.straight,
    turn => FramePose.turn1,
    turnBack => FramePose.turn2,
    smile => FramePose.smile,
    blink => null,
  };
}

/// Why the current step isn't moving, for the line under the circle.
enum FaceHint { noFace, manyFaces, moveCloser, moveBack, lookStraight }

/// One camera frame reduced to what the challenge reads.
///
/// Angles are degrees. Probabilities are 0–1 and null when the detector did
/// not classify the face in that frame (it often doesn't on a turned head).
class FaceSample {
  const FaceSample({
    required this.faceCount,
    this.yaw = 0,
    this.pitch = 0,
    this.roll = 0,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.smiling,
    this.widthRatio = 0,
  });

  const FaceSample.none() : this(faceCount: 0);

  final int faceCount;
  final double yaw;
  final double pitch;
  final double roll;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double? smiling;

  /// The face's width as a share of the frame's short side.
  final double widthRatio;
}

/// Runs one session's steps: straight on first, then the server's order.
class FaceChallenge {
  FaceChallenge(List<ChallengeAction> actions) : steps = _stepsFor(actions);

  /// Pass marks. The live ones are stricter than the server's so the still
  /// photos land well inside what it accepts (it wants 15° per turn; this
  /// asks for 28°).
  static const double minWidth = 0.28;
  static const double maxWidth = 0.85;
  static const double straightMaxYaw = 10;
  static const double straightMaxPitch = 15;
  static const double straightMaxRoll = 15;
  static const double turnMinYaw = 28;
  static const double eyeOpen = 0.6;
  static const double eyeClosed = 0.3;
  static const double smileMin = 0.8;

  /// The still photo's own pass marks — between the live ones and the
  /// server's, so a still the server would refuse is retaken here instead.
  static const double stillStraightMaxYaw = 15;
  static const double stillTurnMinYaw = 18;
  static const double stillSmileMin = 0.5;

  /// Frames a pose must hold before its photo is taken.
  static const int steadyFrames = 3;

  /// Stills the device may refuse for one step before it lets the server
  /// judge. The server re-checks everything, so giving up here can only lead
  /// to a rejection there, never to a false pass.
  static const int stillAttempts = 3;

  final List<ChallengeStep> steps;

  int _index = 0;
  int _steady = 0;
  int _stillFailures = 0;
  bool _capturing = false;
  FaceHint? _hint;

  /// Which way the first turn went, as the live frames see it and as the
  /// still photos do. Tracked apart because the two can be mirrored
  /// differently; each is only ever compared with its own kind.
  int? _liveTurnSign;
  int? _stillTurnSign;

  bool _eyesSeenOpen = false;
  bool _eyesSeenClosed = false;

  /// Straight on first, then the server's order. The second turn becomes
  /// [ChallengeStep.turnBack]. Anything that would not produce all four
  /// photos falls back to a fixed order — a session missing a photo can
  /// only fail.
  static List<ChallengeStep> _stepsFor(List<ChallengeAction> actions) {
    var turns = 0;
    final steps = [
      ChallengeStep.straight,
      for (final action in actions)
        switch (action) {
          ChallengeAction.turn =>
            turns++ == 0 ? ChallengeStep.turn : ChallengeStep.turnBack,
          ChallengeAction.blink => ChallengeStep.blink,
          ChallengeAction.smile => ChallengeStep.smile,
        },
    ];
    final complete =
        steps.length == 5 &&
        ChallengeStep.values.every((step) => steps.contains(step));
    return complete
        ? steps
        : const [
            ChallengeStep.straight,
            ChallengeStep.turn,
            ChallengeStep.turnBack,
            ChallengeStep.blink,
            ChallengeStep.smile,
          ];
  }

  bool get isDone => _index >= steps.length;

  ChallengeStep? get step => isDone ? null : steps[_index];

  /// How many steps are finished — the filled part of the ring.
  int get completed => _index;

  FaceHint? get hint => _hint;

  /// Feed one live frame. Returns the photo to take now when this frame
  /// completes a photo step; frames are ignored while that photo is taken.
  FramePose? onSample(FaceSample s) {
    final step = this.step;
    if (step == null || _capturing) return null;

    if (s.faceCount == 0) return _wait(FaceHint.noFace);
    if (s.faceCount > 1) return _wait(FaceHint.manyFaces);

    // A turned face is narrower, so only the face-on steps judge distance.
    final faceOn = step != ChallengeStep.turn && step != ChallengeStep.turnBack;
    if (faceOn && s.widthRatio < minWidth) return _wait(FaceHint.moveCloser);
    if (faceOn && s.widthRatio > maxWidth) return _wait(FaceHint.moveBack);
    _hint = null;

    switch (step) {
      case ChallengeStep.straight:
        final level =
            s.yaw.abs() <= straightMaxYaw &&
            s.pitch.abs() <= straightMaxPitch &&
            s.roll.abs() <= straightMaxRoll;
        if (!level) return _wait(FaceHint.lookStraight);
        if (!_open(s)) return _wait(null);
        return _hold(FramePose.straight);

      case ChallengeStep.turn:
        if (s.yaw.abs() < turnMinYaw) return null;
        _liveTurnSign = s.yaw.sign.toInt();
        return _take(FramePose.turn1);

      case ChallengeStep.turnBack:
        if (s.yaw.abs() < turnMinYaw) return null;
        if (_liveTurnSign != null && s.yaw.sign.toInt() == _liveTurnSign) {
          return null;
        }
        return _take(FramePose.turn2);

      case ChallengeStep.smile:
        if ((s.smiling ?? 0) < smileMin) return _wait(null);
        return _hold(FramePose.smile);

      case ChallengeStep.blink:
        _trackBlink(s);
        return null;
    }
  }

  /// The still for [pose] came back; [still] is what the detector read from
  /// it. True moves on to the next step; false means take it again — the
  /// person moved between the live frame and the shutter.
  bool acceptStill(FramePose pose, FaceSample still) {
    _capturing = false;
    final shows = still.faceCount == 1 &&
        switch (pose) {
          FramePose.straight => still.yaw.abs() <= stillStraightMaxYaw,
          FramePose.turn1 => still.yaw.abs() >= stillTurnMinYaw,
          FramePose.turn2 =>
            still.yaw.abs() >= stillTurnMinYaw &&
                (_stillTurnSign == null ||
                    still.yaw.sign.toInt() != _stillTurnSign),
          // Unclassified is not a frown; the server makes the final call.
          FramePose.smile => (still.smiling ?? 1) >= stillSmileMin,
        };

    if (!shows && ++_stillFailures < stillAttempts) {
      _steady = 0;
      return false;
    }
    if (pose == FramePose.turn1 && still.faceCount == 1) {
      _stillTurnSign = still.yaw.sign.toInt();
    }
    _advance();
    return true;
  }

  /// The camera could not take the photo; the next frames try again.
  void captureFailed() {
    _capturing = false;
    _steady = 0;
  }

  FramePose? _wait(FaceHint? hint) {
    _hint = hint;
    _steady = 0;
    return null;
  }

  FramePose? _hold(FramePose pose) =>
      ++_steady >= steadyFrames ? _take(pose) : null;

  FramePose _take(FramePose pose) {
    _capturing = true;
    _steady = 0;
    return pose;
  }

  bool _open(FaceSample s) =>
      (s.leftEyeOpen ?? 1) >= eyeOpen && (s.rightEyeOpen ?? 1) >= eyeOpen;

  /// Open, then shut, then open again — something no photo can do.
  void _trackBlink(FaceSample s) {
    final left = s.leftEyeOpen;
    final right = s.rightEyeOpen;
    // Unclassified, or too turned for the reading to mean anything.
    if (left == null || right == null || s.yaw.abs() > 20) return;

    if (left >= eyeOpen && right >= eyeOpen) {
      if (_eyesSeenClosed) {
        _advance();
      } else {
        _eyesSeenOpen = true;
      }
    } else if (left <= eyeClosed && right <= eyeClosed && _eyesSeenOpen) {
      _eyesSeenClosed = true;
    }
  }

  void _advance() {
    _index++;
    _steady = 0;
    _stillFailures = 0;
    _eyesSeenOpen = false;
    _eyesSeenClosed = false;
    _hint = null;
  }
}
