import 'package:dating_app/core/utils/distance_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tap-through profile is the one place the product prints a distance
/// rather than a band, so this is the one place the unit has to be right.
void main() {
  group('formatDistance', () {
    test('close range reads in feet', () {
      expect(formatDistance(30), '100 ft');
      expect(formatDistance(100), '330 ft');
      // Just under the metres threshold.
      expect(formatDistance(149), '490 ft');
    });

    test('a rounding artefact does not become a claim', () {
      // The server rounds to 10 m, so anything under it is noise. "3 ft away"
      // would be a precision the data cannot support.
      expect(formatDistance(0), 'Right here');
      expect(formatDistance(2), 'Right here');
    });

    test('the middle reads in metres', () {
      expect(formatDistance(150), '150 m');
      expect(formatDistance(454), '450 m');
      expect(formatDistance(999), '1000 m');
    });

    test('long range reads in miles', () {
      expect(formatDistance(1000), '0.6 mi');
      expect(formatDistance(4828), '3.0 mi');
      // Past ten miles a decimal is precision nobody acts on.
      expect(formatDistance(32187), '20 mi');
    });

    test('nothing to show stays null rather than becoming zero', () {
      expect(formatDistance(null), isNull);
      expect(formatDistance(double.nan), isNull);
      expect(formatDistance(-5), isNull);
    });

    test('the profile suffix skips the one phrase it would read wrong on', () {
      expect(formatDistanceAway(100), '330 ft away');
      expect(formatDistanceAway(450), '450 m away');
      // Not "Right here away".
      expect(formatDistanceAway(1), 'Right here');
      expect(formatDistanceAway(null), isNull);
    });
  });
}
