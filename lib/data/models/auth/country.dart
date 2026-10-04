import 'package:flutter/foundation.dart';

@immutable
class Country {
  const Country({
    required this.name,
    required this.code,
    required this.flag,
    required this.digits,
  });

  final String name;
  final String code;
  final String flag;

  /// Exact number of digits allowed for this country.
  final int digits;

  static const india =
  Country(name: 'India', code: '+91', flag: '🇮🇳', digits: 10);
  static const us = Country(name: 'US', code: '+1', flag: '🇺🇸', digits: 10);

  @override
  bool operator ==(Object other) => other is Country && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Add more countries here (e.g. UK, UAE) – the UI picks them up automatically.
const List<Country> kCountries = [Country.india, Country.us];