import 'package:dating_app/presentation/verification/face_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// A well-framed face, looking straight at the camera with its eyes open.
FaceSample face({
  double yaw = 0,
  double pitch = 0,
  double left = 0.95,
  double right = 0.95,
  double? smiling = 0.1,
  double width = 0.45,
  int count = 1,
}) => FaceSample(
  faceCount: count,
  yaw: yaw,
  pitch: pitch,
  leftEyeOpen: left,
  rightEyeOpen: right,
  smiling: smiling,
  widthRatio: width,
);

/// Feeds [sample] until the challenge asks for a photo (or gives up).
FramePose? hold(FaceChallenge c, FaceSample sample, {int frames = 10}) {
  for (var i = 0; i < frames; i++) {
    final pose = c.onSample(sample);
    if (pose != null) return pose;
  }
  return null;
}

void main() {
  const order = [
    ChallengeAction.blink,
    ChallengeAction.turn,
    ChallengeAction.smile,
    ChallengeAction.turn,
  ];

  group('steps', () {
    test('start straight on, then follow the server, second turn going back', () {
      expect(FaceChallenge(order).steps, [
        ChallengeStep.straight,
        ChallengeStep.blink,
        ChallengeStep.turn,
        ChallengeStep.smile,
        ChallengeStep.turnBack,
      ]);
    });

    test('fall back to a fixed order when the server sent an incomplete one', () {
      final c = FaceChallenge(const [ChallengeAction.turn, ChallengeAction.smile]);

      expect(c.steps, [
        ChallengeStep.straight,
        ChallengeStep.turn,
        ChallengeStep.turnBack,
        ChallengeStep.blink,
        ChallengeStep.smile,
      ]);
    });

    test('parse the wire names', () {
      expect(ChallengeAction.fromWire('blink'), ChallengeAction.blink);
      expect(ChallengeAction.fromWire('wink'), isNull);
      expect(FramePose.fromWire('turn_2'), FramePose.turn2);
      expect(FramePose.turn1.wire, 'turn_1');
    });
  });

  group('straight on', () {
    test('takes the photo once the face holds still', () {
      final c = FaceChallenge(order);

      expect(c.onSample(face()), isNull);
      expect(c.onSample(face()), isNull);
      expect(c.onSample(face()), FramePose.straight);
    });

    test('ignores frames while the photo is being taken', () {
      final c = FaceChallenge(order);
      hold(c, face());

      expect(c.onSample(face()), isNull);
    });

    test('says what is wrong', () {
      final c = FaceChallenge(order);

      c.onSample(const FaceSample.none());
      expect(c.hint, FaceHint.noFace);
      c.onSample(face(count: 2));
      expect(c.hint, FaceHint.manyFaces);
      c.onSample(face(width: 0.15));
      expect(c.hint, FaceHint.moveCloser);
      c.onSample(face(width: 0.95));
      expect(c.hint, FaceHint.moveBack);
      c.onSample(face(yaw: 22));
      expect(c.hint, FaceHint.lookStraight);
      c.onSample(face());
      expect(c.hint, isNull);
    });

    test('waits for open eyes', () {
      final c = FaceChallenge(order);

      expect(hold(c, face(left: 0.1, right: 0.1)), isNull);
    });

    test('a break in the pose starts the count again', () {
      final c = FaceChallenge(order);
      c.onSample(face());
      c.onSample(face());
      c.onSample(face(yaw: 25));

      expect(c.onSample(face()), isNull);
      expect(c.onSample(face()), isNull);
      expect(c.onSample(face()), FramePose.straight);
    });
  });

  /// A challenge already past the straight-on photo.
  FaceChallenge pastStraight(List<ChallengeAction> actions) {
    final c = FaceChallenge(actions);
    hold(c, face());
    expect(c.acceptStill(FramePose.straight, face()), isTrue);
    return c;
  }

  group('blink', () {
    test('needs open, shut, then open again', () {
      final c = pastStraight(order);
      expect(c.step, ChallengeStep.blink);

      c.onSample(face());
      c.onSample(face(left: 0.05, right: 0.1));
      expect(c.step, ChallengeStep.blink);
      c.onSample(face());

      expect(c.step, ChallengeStep.turn);
    });

    test('does not count eyes that were never seen open first', () {
      final c = pastStraight(order);

      c.onSample(face(left: 0.05, right: 0.05));
      c.onSample(face());

      expect(c.step, ChallengeStep.blink);
    });

    test('ignores frames the detector could not classify', () {
      final c = pastStraight(order);

      c.onSample(face());
      c.onSample(const FaceSample(faceCount: 1, widthRatio: 0.45));
      c.onSample(face());

      expect(c.step, ChallengeStep.blink);
    });
  });

  group('turns', () {
    const turnsFirst = [
      ChallengeAction.turn,
      ChallengeAction.turn,
      ChallengeAction.blink,
      ChallengeAction.smile,
    ];

    test('either way first, then the other way', () {
      final c = pastStraight(turnsFirst);

      expect(c.onSample(face(yaw: 12, width: 0.3)), isNull);
      expect(c.onSample(face(yaw: -33, width: 0.3)), FramePose.turn1);
      expect(c.acceptStill(FramePose.turn1, face(yaw: -30)), isTrue);

      // Turning the same way again does nothing.
      expect(c.onSample(face(yaw: -40, width: 0.3)), isNull);
      expect(c.onSample(face(yaw: 31, width: 0.3)), FramePose.turn2);
    });

    test('do not ask a turned face to move closer', () {
      final c = pastStraight(turnsFirst);

      expect(c.onSample(face(yaw: 35, width: 0.2)), FramePose.turn1);
      expect(c.hint, isNull);
    });

    test('retake a still that did not catch the turn', () {
      final c = pastStraight(turnsFirst);
      c.onSample(face(yaw: 35));

      expect(c.acceptStill(FramePose.turn1, face(yaw: 6)), isFalse);
      expect(c.step, ChallengeStep.turn);
      expect(c.onSample(face(yaw: 35)), FramePose.turn1);
    });

    test('compare the second still with the first still, not the live frames', () {
      final c = pastStraight(turnsFirst);
      c.onSample(face(yaw: 35));
      c.acceptStill(FramePose.turn1, face(yaw: 30));
      c.onSample(face(yaw: -35));

      // Same way as the first still: refused, even though the live frame was
      // the other way (the stills may be mirrored differently).
      expect(c.acceptStill(FramePose.turn2, face(yaw: 28)), isFalse);
      c.onSample(face(yaw: -35));
      expect(c.acceptStill(FramePose.turn2, face(yaw: -29)), isTrue);
    });

    test('let the server judge after three refused stills', () {
      final c = pastStraight(turnsFirst);
      for (var i = 0; i < FaceChallenge.stillAttempts - 1; i++) {
        c.onSample(face(yaw: 35));
        expect(c.acceptStill(FramePose.turn1, face(yaw: 5)), isFalse);
      }
      c.onSample(face(yaw: 35));

      expect(c.acceptStill(FramePose.turn1, face(yaw: 5)), isTrue);
      expect(c.step, ChallengeStep.turnBack);
    });
  });

  group('smile', () {
    test('holds a real smile before taking the photo', () {
      final c = pastStraight(const [
        ChallengeAction.smile,
        ChallengeAction.turn,
        ChallengeAction.turn,
        ChallengeAction.blink,
      ]);

      expect(c.onSample(face(smiling: 0.5)), isNull);
      expect(hold(c, face(smiling: 0.92)), FramePose.smile);
      expect(c.acceptStill(FramePose.smile, face(smiling: 0.7)), isTrue);
      expect(c.step, ChallengeStep.turn);
    });
  });

  test('a full run takes all four photos and finishes', () {
    final c = FaceChallenge(order);
    final taken = <FramePose>[];

    void take(FaceSample live, FaceSample still) {
      final pose = hold(c, live);
      expect(pose, isNotNull);
      taken.add(pose!);
      expect(c.acceptStill(pose, still), isTrue);
    }

    take(face(), face());
    c
      ..onSample(face())
      ..onSample(face(left: 0, right: 0))
      ..onSample(face());
    take(face(yaw: 34), face(yaw: 31));
    take(face(smiling: 0.95), face(smiling: 0.9));
    take(face(yaw: -34), face(yaw: -30));

    expect(c.isDone, isTrue);
    expect(c.completed, c.steps.length);
    expect(taken, [
      FramePose.straight,
      FramePose.turn1,
      FramePose.smile,
      FramePose.turn2,
    ]);
  });
}
