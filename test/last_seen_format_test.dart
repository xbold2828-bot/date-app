import 'package:dating_app/core/utils/last_seen_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Last seen" is a claim about somebody's habits as much as their whereabouts,
/// so what this refuses to print matters as much as what it does.
void main() {
  DateTime ago(Duration d) => DateTime.now().subtract(d);

  group('presence wins', () {
    test('online beats any timestamp', () {
      expect(
        formatLastSeen(ago(const Duration(hours: 3)), isOnline: true),
        'Online now',
      );
    });

    test('online with no timestamp at all still says so', () {
      // Presence comes off the socket; the mirrored timestamp lags it.
      expect(formatLastSeen(null, isOnline: true), 'Online now');
    });
  });

  group('nothing to say', () {
    test('is null rather than a guess', () {
      expect(formatLastSeen(null), isNull);
    });
  });

  group('the recent past', () {
    test('under a minute is "Just now"', () {
      expect(formatLastSeen(ago(const Duration(seconds: 20))), 'Just now');
    });

    test('minutes', () {
      expect(formatLastSeen(ago(const Duration(minutes: 12))), '12m ago');
    });

    test('hours', () {
      expect(formatLastSeen(ago(const Duration(hours: 3))), '3h ago');
    });

    test('one day is "Yesterday", not "1d ago"', () {
      expect(formatLastSeen(ago(const Duration(days: 1, hours: 2))),
          'Yesterday');
    });

    test('days', () {
      expect(formatLastSeen(ago(const Duration(days: 6))), '6d ago');
    });

    test('weeks', () {
      expect(formatLastSeen(ago(const Duration(days: 15))), '2w ago');
    });
  });

  group('the distant past', () {
    test('stops counting past a month', () {
      // "9w ago" is a date somebody can work backwards from, and nobody makes
      // a different decision on it than on "a while".
      expect(formatLastSeen(ago(const Duration(days: 200))), 'A while ago');
    });

    test('the boundary lands on the vague side', () {
      expect(formatLastSeen(ago(const Duration(days: 31))), 'A while ago');
    });
  });

  group('bad clocks', () {
    test('a future timestamp reads as now, not as "in 3 minutes"', () {
      expect(
        formatLastSeen(DateTime.now().add(const Duration(minutes: 3))),
        'Just now',
      );
    });
  });

  group('what it never prints', () {
    test('no clock times and no calendar dates, at any age', () {
      for (final d in [
        const Duration(minutes: 1),
        const Duration(hours: 5),
        const Duration(days: 1),
        const Duration(days: 3),
        const Duration(days: 20),
        const Duration(days: 400),
      ]) {
        final text = formatLastSeen(ago(d))!;
        // A pattern of life is what a card must not hand over: no "23:04",
        // no "3 March", no year.
        expect(text, isNot(contains(':')));
        expect(text, isNot(matches(RegExp(r'\b(19|20)\d{2}\b'))));
        expect(
          text.toLowerCase(),
          isNot(matches(RegExp(
              r'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|am|pm'))),
        );
      }
    });
  });
}
