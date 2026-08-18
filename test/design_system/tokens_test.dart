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
    // These are the promises the palette makes, and they are made twice — once
    // per mode. A dark theme is exactly where a token quietly stops being
    // legible, because the person who added it was looking at the light one.

    final palettes = {
      'light': RadiusPalette.light,
      'dark': RadiusPalette.dark,
    };

    palettes.forEach((name, p) {
      group(name, () {
        test('primary text is AAA on the app background', () {
          expect(contrast(p.textDark, p.background), greaterThanOrEqualTo(7.0));
        });

        test('secondary text meets AA on background, panel and card', () {
          for (final ground in [p.background, p.panel, p.card]) {
            expect(
              contrast(p.textGrey, ground),
              greaterThanOrEqualTo(4.5),
              reason: 'textGrey must stay readable on $ground',
            );
          }
        });

        test('the accent is a control colour, and primaryInk is the text one',
            () {
          // The brand blue is #4A7FE8 by specification, which is 3.8:1 on
          // white: enough for a filled button or an active tab, not enough for
          // a word. That is why there are two of them, and why swapping one
          // for the other is a bug rather than a preference.
          expect(
            contrast(p.primary, p.background),
            greaterThanOrEqualTo(3.0),
            reason: 'primary must clear the UI-component bar',
          );
          expect(
            contrast(p.onAccent, p.primary),
            greaterThanOrEqualTo(3.0),
            reason: 'a filled button has to be readable',
          );
          expect(
            contrast(p.primaryInk, p.background),
            greaterThanOrEqualTo(4.5),
            reason: 'primaryInk is the one that sets accent-coloured text',
          );
        });

        test('premium ink is AA on the background and on its own tint', () {
          expect(contrast(p.premiumInk, p.background),
              greaterThanOrEqualTo(4.5));
          expect(contrast(p.premiumInk, p.premiumTint),
              greaterThanOrEqualTo(4.5));
          expect(contrast(p.onAccent, p.premium), greaterThanOrEqualTo(3.0));
        });

        test('selected chip label is readable on its tinted fill', () {
          expect(
            contrast(p.primaryInk, p.primaryTint),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('error text is AA on the background', () {
          expect(contrast(p.danger, p.background), greaterThanOrEqualTo(4.5));
        });

        test('iconMuted clears the 3:1 bar for non-text UI', () {
          // Deliberately NOT held to 4.5 — it is documented as non-text only.
          final ratio = contrast(p.iconMuted, p.background);
          expect(ratio, greaterThanOrEqualTo(3.0));
          expect(
            ratio,
            lessThan(4.5),
            reason:
                'If this ever passes 4.5, fold it into textGrey and delete it '
                'rather than keeping two greys that mean the same thing.',
          );
        });
      });
    });

    test('the light ground is pure white, edge to edge', () {
      // Background, panel and card are one colour by design; separation comes
      // from the hairline, not from tinted surfaces. A "slightly off-white"
      // card is the first step back to the old cream.
      const white = Color(0xFFFFFFFF);
      expect(RadiusPalette.light.background, white);
      expect(RadiusPalette.light.panel, white);
      expect(RadiusPalette.light.card, white);
    });

    test('the two palettes never share an ink or a ground', () {
      // A token that forgot to change is the one bug a per-palette contrast
      // check cannot see: it passes both groups above and still renders a
      // white card in dark mode.
      const light = RadiusPalette.light;
      const dark = RadiusPalette.dark;
      for (final (name, a, b) in [
        ('background', light.background, dark.background),
        ('panel', light.panel, dark.panel),
        ('card', light.card, dark.card),
        ('textDark', light.textDark, dark.textDark),
        ('textGrey', light.textGrey, dark.textGrey),
        ('iconMuted', light.iconMuted, dark.iconMuted),
        ('inputBorder', light.inputBorder, dark.inputBorder),
        ('primary', light.primary, dark.primary),
        ('premium', light.premium, dark.premium),
        ('onAccent', light.onAccent, dark.onAccent),
      ]) {
        expect(a, isNot(b), reason: '$name is the same in both modes');
      }
    });

    test('onImage stays white in both modes', () {
      // It sits on a photograph, and a photograph does not change colour with
      // the theme.
      expect(AppColors.onImage, const Color(0xFFFFFFFF));
    });
  });

  group('palette swap', () {
    tearDown(() => AppColors.use(Brightness.light));

    test('the façade follows the active palette', () {
      AppColors.use(Brightness.light);
      expect(AppColors.background, RadiusPalette.light.background);
      expect(AppColors.isDark, isFalse);

      AppColors.use(Brightness.dark);
      expect(AppColors.background, RadiusPalette.dark.background);
      expect(AppColors.card, RadiusPalette.dark.card);
      expect(AppColors.isDark, isTrue);
    });

    test('use() reports whether anything actually changed', () {
      // PaletteScope only sweeps the element tree when this says true, so a
      // false positive here is a rebuild of the whole app on every frame.
      AppColors.use(Brightness.light);
      expect(AppColors.use(Brightness.light), isFalse);
      expect(AppColors.use(Brightness.dark), isTrue);
      expect(AppColors.use(Brightness.dark), isFalse);
    });

    test('the type tokens re-resolve rather than freezing on first read', () {
      // They were `static final` before the swap existed, which would have
      // captured whichever palette happened to be active first.
      AppColors.use(Brightness.light);
      final lightBody = AppTextStyles.body.color;
      AppColors.use(Brightness.dark);
      expect(AppTextStyles.body.color, isNot(lightBody));
      expect(AppTextStyles.body.color, RadiusPalette.dark.textDark);
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
      for (final (theme, p) in [
        (AppTheme.light, RadiusPalette.light),
        (AppTheme.dark, RadiusPalette.dark),
      ]) {
        expect(theme.scaffoldBackgroundColor, p.background);
        expect(theme.colorScheme.primary, p.primary);
        expect(theme.colorScheme.onPrimary, p.onAccent);
        expect(theme.colorScheme.surface, p.card);
        expect(theme.brightness, p.brightness);
      }
    });

    test('the dark theme is built from the dark palette, whichever is active',
        () {
      // AppTheme reads the palette it is handed rather than AppColors, because
      // both themes are constructed before the app has decided which one it is
      // showing. Building the dark theme while light is active used to bake
      // white into it.
      AppColors.use(Brightness.light);
      final dark = AppTheme.dark;
      AppColors.use(Brightness.light);

      expect(dark.scaffoldBackgroundColor, RadiusPalette.dark.background);
      expect(dark.textTheme.bodyMedium?.color, RadiusPalette.dark.textDark);
      expect(
        dark.elevatedButtonTheme.style?.textStyle
            ?.resolve(<WidgetState>{})?.color,
        RadiusPalette.dark.onAccent,
      );
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
