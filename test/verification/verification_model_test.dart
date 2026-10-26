import 'package:dating_app/data/models/verification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a started check keeps its order and its four upload slots', () {
    final start = VerificationStart.fromJson({
      'sessionId': 's1',
      'challenge': ['smile', 'turn', 'wink', 'blink', 'turn'],
      'uploads': [
        for (final pose in ['straight', 'turn_1', 'turn_2', 'smile'])
          {
            'pose': pose,
            'url': 'https://s3.example/$pose.jpg?sig',
            'headers': {'Content-Type': 'image/jpeg'},
          },
        {'pose': 'selfie', 'url': 'https://s3.example/x'},
      ],
      'expiresAt': '2026-10-26T10:00:00.000Z',
    });

    expect(start.sessionId, 's1');
    // An action this build doesn't know is dropped, not guessed at.
    expect(start.challenge, [
      ChallengeAction.smile,
      ChallengeAction.turn,
      ChallengeAction.blink,
      ChallengeAction.turn,
    ]);
    expect(start.uploads.map((u) => u.pose), FramePose.values);
    expect(start.uploads.first.headers, {'Content-Type': 'image/jpeg'});
  });

  test('a result with photos in the way lists them', () {
    final result = VerificationResult.fromJson({
      'outcome': 'photos_blocking',
      'verified': false,
      'message': 'Remove them to get verified.',
      'blockingPhotos': [
        {'mediaId': 'p2', 'reason': 'not_you'},
        {'mediaId': 'p5', 'reason': 'unreadable'},
      ],
    });

    expect(result.outcome, VerificationOutcome.photosBlocking);
    expect(result.blockingPhotos.map((p) => p.mediaId), ['p2', 'p5']);
    expect(result.blockingPhotos.last.isUnreadable, isTrue);
  });

  test('an outcome this build does not know reads as not verified', () {
    final result = VerificationResult.fromJson({'outcome': 'something_new'});

    expect(result.outcome, VerificationOutcome.rejected);
    expect(result.verified, isFalse);
  });

  test('status reads availability and when the tick was earned', () {
    final status = VerificationStatus.fromJson({
      'verified': true,
      'verificationStatus': 'verified',
      'available': false,
      'verifiedAt': '2026-10-01T10:00:00.000Z',
      'verifiedUntil': '2027-10-01T10:00:00.000Z',
    });

    expect(status.available, isFalse);
    expect(status.verifiedAt, DateTime.utc(2026, 10, 1, 10));
    expect(status.verifiedUntil, DateTime.utc(2027, 10, 1, 10));
  });
}
