import 'dart:io';

import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every glyph these fonts will ever have to fit, including the deep
/// descenders that get clipped first.
const _probe = 'Ojpqgy Anything';

double _heightOf(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: _probe, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, path) in [
      ('Fraunces', 'assets/fonts/Fraunces.ttf'),
      ('DM Sans', 'assets/fonts/DMSans.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(File(path).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
  });

  /// A `height` multiplier tighter than the font's own ascent + descent
  /// squeezes the line box below the glyphs, and descenders — g, y, p — get
  /// sliced off. It looks like a rendering glitch rather than a type setting,
  /// so it is easy to stare past.
  test('no token sets a line box shorter than its glyphs need', () {
    final tokens = <String, TextStyle>{
      'display': AppTextStyles.display,
      'title': AppTextStyles.title,
      'hero': AppTextStyles.hero,
      'body': AppTextStyles.body,
      'bodyStrong': AppTextStyles.bodyStrong,
      'bodyMuted': AppTextStyles.bodyMuted,
      'button': AppTextStyles.button,
      'caption': AppTextStyles.caption,
      'eyebrow': AppTextStyles.eyebrow,
      'label': AppTextStyles.label,
      'chip': AppTextStyles.chip,
      'chipSelected': AppTextStyles.chipSelected,
      // avatarInitial is deliberately excluded: it renders one capital and
      // nothing else, so it has no descender to clip, and reserving the space
      // would push the letter off-centre in its circle. See its doc comment.
    };

    final failures = <String>[];

    tokens.forEach((name, style) {
      final styled = _heightOf(style);
      // The same style with the multiplier removed: what the font itself
      // says it needs.
      final natural = _heightOf(
        TextStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontVariations: style.fontVariations,
        ),
      );

      if (styled < natural - 0.01) {
        failures.add(
          '$name: line box ${styled.toStringAsFixed(2)}px is shorter than the '
          '${natural.toStringAsFixed(2)}px its glyphs need '
          '(height: ${style.height})',
        );
      }
    });

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
