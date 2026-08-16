/// How far away somebody is, in the unit that suits the number.
///
/// The tap-through profile is the one surface that prints a distance rather
/// than a band. Everywhere else — grid cards, the map, any list — still says
/// "2-5 km", because a number in a list is a number about a stranger you have
/// not opened.
///
/// The scale is deliberately mixed, and it is the scale the product asked for:
/// feet up close, metres in the middle, miles once it stops being a walk.
/// Reading "0.06 mi" tells nobody anything; "190 ft" does.
library;

const double _feetPerMetre = 3.28084;
const double _metresPerMile = 1609.344;

/// Under this, distance reads in feet — close enough that a person thinks in
/// paces rather than blocks.
const double _feetUpTo = 150;

/// Under this, metres. Above it, miles.
const double _metresUpTo = 1000;

/// "190 ft" · "450 m" · "2.4 mi", or null when there is no distance to show.
///
/// The server rounds to the nearest 10 m before this ever sees it, so the
/// precision here is presentational — rounding again on top is what keeps
/// "312 ft" from implying a survey.
String? formatDistance(num? metres) {
  if (metres == null || metres.isNaN || metres < 0) return null;

  final m = metres.toDouble();

  if (m < _feetUpTo) {
    final feet = m * _feetPerMetre;
    // Under ten feet is "right here" — a number that small is noise from the
    // rounding, and printing it would be a claim the data cannot support.
    if (feet < 10) return 'Right here';
    return '${_toNearest(feet, 10)} ft';
  }

  if (m < _metresUpTo) return '${_toNearest(m, 10)} m';

  final miles = m / _metresPerMile;
  // One decimal up to ten miles, then whole miles: "12.4 mi" is a precision
  // nobody acts on.
  return miles < 10
      ? '${miles.toStringAsFixed(1)} mi'
      : '${miles.round()} mi';
}

/// The same thing with the trailing word the profile prints: "190 ft away".
String? formatDistanceAway(num? metres) {
  final value = formatDistance(metres);
  if (value == null) return null;
  return value == 'Right here' ? value : '$value away';
}

int _toNearest(double value, int step) => (value / step).round() * step;
