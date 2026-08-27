import 'package:flutter/services.dart';

final List<TextInputFormatter> textInputFormatters = [
  // ❌ Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  // Allow only letters and space
  // ❌ Block multiple consecutive spaces
  FilteringTextInputFormatter.deny(RegExp(r' {2,}')),

  // ✅ Allow only letters and single spaces
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
];

final List<TextInputFormatter> swiftInputFormatters = [
  // ❌ Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  // ❌ Block multiple consecutive spaces
  FilteringTextInputFormatter.deny(RegExp(r' {2,}')),

  // ✅ Allow letters, numbers, and space
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
];

final List<TextInputFormatter> textInput500Limit = [
  /// ❌ Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  /// ❌ Block multiple consecutive spaces
  FilteringTextInputFormatter.deny(RegExp(r' {2,}')),

  /// ✅ Allow letters, numbers, space & new line
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \n]')),

  /// 🔒 Limit to maximum 500 characters
  LengthLimitingTextInputFormatter(500),
];

final List<TextInputFormatter> everythingExceptDoubleSpace = [
  /// ❌ Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  /// ❌ Block multiple consecutive spaces
  FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
];

final List<TextInputFormatter> textInput60Limit = [
  /// ❌ Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  /// ❌ Block multiple consecutive spaces
  FilteringTextInputFormatter.deny(RegExp(r' {2,}')),

  /// ✅ Allow letters, numbers, space & new line
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \n]')),

  /// 🔒 Limit to maximum 500 characters
  LengthLimitingTextInputFormatter(60),
];

final List<TextInputFormatter> ibanInputFormatters = [
  // ✅ Allow only letters & numbers
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),

  // ✅ Limit to 24 characters
  LengthLimitingTextInputFormatter(24),

  // ✅ Convert to uppercase
  TextInputFormatter.withFunction((oldValue, newValue) {
    final upperText = newValue.text.toUpperCase();
    return newValue.copyWith(text: upperText, selection: newValue.selection);
  }),
];

final List<TextInputFormatter> zeroNotAllowedInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
  TextInputFormatter.withFunction((oldValue, newValue) {
    // If first character is 0, block it
    if (newValue.text.length == 1 && newValue.text == '0') {
      return oldValue;
    }
    return newValue;
  }),
];

final List<TextInputFormatter> urlInputFormatters = [
  // Block leading space
  FilteringTextInputFormatter.deny(RegExp(r'^ ')),

  // Allow valid URL characters
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9:/._\-?=&%#]')),
];

final List<TextInputFormatter> numberInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
];

final List<TextInputFormatter> noSpaceInputFormatters = [
  FilteringTextInputFormatter.deny(RegExp(r'\s')),
];
