import 'dart:io';
import 'dart:math' as math;

import 'package:dating_app/core/constants/app_colors.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio, 1..21.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('colour contrast', () {
    // These are the promises the palette makes. The design is deliberately
    // low-contrast warm neutrals, which is exactly the kind of palette that
    // drifts below the line one "slightly lighter grey" at a time.

    test('primary text is AAA on the app background', () {
      expect(
        contrast(AppColors.textDark, AppColors.background),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('secondary text meets AA on the app background', () {
      // The reference design's muted grey sits at 3.28:1 here and fails. This
      // is the darker replacement; if someone "restores" the original value,
      // this test is what stops it.
      expect(
        contrast(AppColors.textGrey, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('secondary text meets AA on panels and cards too', () {
      for (final ground in [AppColors.panel, AppColors.white]) {
        expect(
          contrast(AppColors.textGrey, ground),
          greaterThanOrEqualTo(4.5),
          reason: 'textGrey must stay readable on $ground',
        );
      }
    });

    test('primary is AA as text and as a control', () {
      expect(
        contrast(AppColors.primary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('selected chip label is readable on its tinted fill', () {
      expect(
        contrast(AppColors.primaryDeep, AppColors.primaryTint),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('iconMuted clears the 3:1 bar for non-text UI', () {
      // Deliberately NOT held to 4.5 — it is documented as non-text only.
      final ratio = contrast(AppColors.iconMuted, AppColors.background);
      expect(ratio, greaterThanOrEqualTo(3.0));
      expect(
        ratio,
        lessThan(4.5),
        reason: 'If this ever passes 4.5, fold it into textGrey and delete it '
            'rather than keeping two greys that mean the same thing.',
      );
    });
  });

  group('type tokens', () {
    test('display faces are Fraunces, UI faces are DM Sans', () {
      for (final style in [
        AppTextStyles.display,
        AppTextStyles.title,
        AppTextStyles.hero,
        AppTextStyles.avatarInitial(30),
      ]) {
        expect(style.fontFamily, 'Fraunces');
      }
      for (final style in [
        AppTextStyles.body,
        AppTextStyles.bodyStrong,
        AppTextStyles.bodyMuted,
        AppTextStyles.button,
        AppTextStyles.caption,
        AppTextStyles.eyebrow,
        AppTextStyles.label,
        AppTextStyles.chip,
        AppTextStyles.chipSelected,
      ]) {
        expect(style.fontFamily, 'DM Sans');
      }
    });

    test('every token sets an optical size', () {
      // `opsz` has no TextStyle field, so it can only arrive via
      // fontVariations. A token missing it renders at the wrong optical size
      // and looks subtly slack — the kind of thing nobody files a bug for.
      final tokens = <String, TextStyle>{
        'display': AppTextStyles.display,
        'title': AppTextStyles.title,
        'hero': AppTextStyles.hero,
        'body': AppTextStyles.body,
        'button': AppTextStyles.button,
        'caption': AppTextStyles.caption,
        'eyebrow': AppTextStyles.eyebrow,
        'label': AppTextStyles.label,
        'chip': AppTextStyles.chip,
      };
      tokens.forEach((name, style) {
        expect(
          style.fontVariations?.any((v) => v.axis == 'opsz'),
          isTrue,
          reason: '$name is missing an opsz variation',
        );
      });
    });

    test('optical size stays inside each family\'s axis range', () {
      // DM Sans tops out at opsz 40; Fraunces at 144. Asking for an
      // out-of-range instance is undefined behaviour, so the tokens clamp.
      double opszOf(TextStyle s) =>
          s.fontVariations!.firstWhere((v) => v.axis == 'opsz').value;

      expect(opszOf(AppTextStyles.body), inInclusiveRange(9, 40));
      expect(opszOf(AppTextStyles.button), inInclusiveRange(9, 40));
      // A caller asking for an absurd avatar clamps rather than breaking.
      expect(opszOf(AppTextStyles.avatarInitial(400)), lessThanOrEqualTo(144));
      expect(opszOf(AppTextStyles.avatarInitial(1)), greaterThanOrEqualTo(9));
    });
  });

  group('theme wiring', () {
    test('display slots keep Fraunces and body slots get DM Sans', () {
      // Regression guard for a real bug: TextTheme.apply(fontFamily:)
      // overwrites the family on *every* slot, so applying it after the token
      // copyWith silently renders the entire app in DM Sans.
      final text = AppTheme.light.textTheme;

      expect(text.displayLarge?.fontFamily, 'Fraunces');
      expect(text.headlineMedium?.fontFamily, 'Fraunces');
      expect(text.titleLarge?.fontFamily, 'Fraunces');

      expect(text.bodyMedium?.fontFamily, 'DM Sans');
      expect(text.bodySmall?.fontFamily, 'DM Sans');
      expect(text.labelMedium?.fontFamily, 'DM Sans');
    });

    test('unstyled text inherits DM Sans rather than Roboto', () {
      // bodyMedium is what a bare Text() resolves to, and what every
      // screen-local TextStyle merges on top of. It is the single reason the
      // typeface reaches screens this migration has not touched yet.
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    });

    test('scaffold and colour scheme come from the tokens', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.white);
    });
  });

  group('font assets', () {
    // The quiet failure mode: assets missing or misnamed, everything falls
    // back to Roboto, and the app still builds and runs looking wrong.
    setUpAll(() async {
      for (final (family, path) in [
        ('Fraunces', 'assets/fonts/Fraunces.ttf'),
        ('DM Sans', 'assets/fonts/DMSans.ttf'),
      ]) {
        final loader = FontLoader(family)
          ..addFont(
            File(path).readAsBytes().then((b) => b.buffer.asByteData()),
          );
        await loader.load();
      }
    });

    test('the declared font files exist and are non-trivial', () {
      for (final path in [
        'assets/fonts/Fraunces.ttf',
        'assets/fonts/DMSans.ttf',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        expect(file.lengthSync(), greaterThan(50000));
      }
    });

    double widthOf(TextStyle style, [String text = 'Handgloves']) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    test('the two families render at different metrics', () {
      // If both resolved to the same fallback, these would be equal.
      final serif = widthOf(AppTextStyles.display);
      final sans = widthOf(
        AppTextStyles.body.copyWith(fontSize: AppTextStyles.display.fontSize),
      );
      expect(serif, isNot(closeTo(sans, 0.5)));
    });

    test('weight actually changes the rendering', () {
      final regular = widthOf(AppTextStyles.body);
      final bold = widthOf(AppTextStyles.body.copyWith(
        fontVariations: const [FontVariation('wght', 700)],
      ));
      expect(bold, greaterThan(regular));
    });
  });
}
