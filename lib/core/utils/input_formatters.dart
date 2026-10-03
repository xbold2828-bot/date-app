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

/// Keeps digits only, at most the sum of [groups], and shows them spaced in
/// those groups — `[5, 5]` turns 9876543210 into "98765 43210".
///
/// A grouped number is one a person can check against the one in their head;
/// ten digits in a row is not. Read the value back with [digitsOf], never as
/// the raw text.
class DigitGroupsFormatter extends TextInputFormatter {
  DigitGroupsFormatter(this.groups);

  final List<int> groups;

  int get maxDigits => groups.fold(0, (sum, g) => sum + g);

  /// The digits in [text], without the spacing this formatter adds.
  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final cursor = newValue.selection.baseOffset < 0
        ? raw.length
        : newValue.selection.baseOffset.clamp(0, raw.length);

    final digits = StringBuffer();
    var digitsBeforeCursor = 0;
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c < 0x30 || c > 0x39 || digits.length >= maxDigits) continue;
      digits.writeCharCode(c);
      if (i < cursor) digitsBeforeCursor++;
    }
    var value = digits.toString();

    // Backspace over one of our spaces removes nothing a person can see, so
    // treat it as deleting the digit before it — otherwise the cursor just
    // bounces back over the space and the key appears dead.
    final deletedOnlySpacing = newValue.text.length < oldValue.text.length &&
        value == digitsOf(oldValue.text);
    if (deletedOnlySpacing && digitsBeforeCursor > 0) {
      value = value.substring(0, digitsBeforeCursor - 1) +
          value.substring(digitsBeforeCursor);
      digitsBeforeCursor--;
    }

    final out = StringBuffer();
    var offset = 0;
    var group = 0;
    var inGroup = 0;
    for (var i = 0; i < value.length; i++) {
      if (group < groups.length - 1 && inGroup == groups[group]) {
        out.write(' ');
        group++;
        inGroup = 0;
      }
      out.write(value[i]);
      inGroup++;
      if (i + 1 == digitsBeforeCursor) offset = out.length;
    }

    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
