/// The type scale, carried over from the Kotlin app's `ui/theme/Type.kt`.
///
/// Cairo for everything the user reads, Inter for figures. Both are the same
/// variable font files the Android app ships, copied into `assets/fonts/`, so
/// text measures the same on both clients.
///
/// Weight is applied through `fontVariations` on the `wght` axis and not only
/// through `fontWeight`. With a variable font, `fontWeight` alone leaves the
/// engine to synthesise a weight — thickening the outline geometrically — which
/// on Arabic looks like a smudge rather than a bolder cut.
///
/// Hierarchy is built from size, weight and opacity. Not from bolding
/// everything: if every line is bold, none of them is.
library;

import 'package:flutter/material.dart';

/// The Arabic and Latin text face.
const String kZadArabicFont = 'Cairo';

/// The figures face. Used for money and dates, where even digit widths matter
/// more than character.
const String kZadFigureFont = 'Inter';

List<FontVariation> _wght(double weight) => <FontVariation>[
  FontVariation('wght', weight),
];

/// The type scale.
abstract final class ZadType {
  /// 32/38, tight. A screen's one big number.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 32,
    height: 38 / 32,
    letterSpacing: -0.5,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// 26/32.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 26,
    height: 32 / 26,
    letterSpacing: -0.4,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// 28/34 — a screen title.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// 22/28 — a section title.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.2,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// 20/26 — a card title.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// 18/24.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 18,
    height: 24 / 18,
    letterSpacing: 0.1,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// 15/20 — a row's leading label.
  static const TextStyle titleSmall = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 15,
    height: 20 / 15,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// 15/22 — body.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 15,
    height: 22 / 15,
    letterSpacing: 0.2,
    decoration: TextDecoration.none,
  );

  /// 14/20.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.none,
  );

  /// 13/18 — a caption.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0.2,
    decoration: TextDecoration.none,
  );

  /// 13/18 — a button's label.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// 12/16.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.none,
  );

  /// 11/15 — the smallest label that stays legible.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: kZadArabicFont,
    fontSize: 11,
    height: 15 / 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.none,
  );

  /// A money figure.
  ///
  /// Inter with `tnum`, so digits are all the same width: a ticking balance
  /// must not make the row jitter as it counts. Negative tracking because large
  /// figures set at default spacing look loose.
  static TextStyle figure(double size) => TextStyle(
    fontFamily: kZadFigureFont,
    fontSize: size,
    height: 1.05,
    letterSpacing: -size * 0.03,
    fontWeight: FontWeight.bold,
    fontVariations: _wght(700),
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );

  /// The whole scale with the `wght` axis applied, which is what the theme
  /// uses.
  static TextTheme get textTheme => TextTheme(
    displayLarge: _axis(displayLarge),
    displayMedium: _axis(displayMedium),
    headlineLarge: _axis(headlineLarge),
    headlineMedium: _axis(headlineMedium),
    titleLarge: _axis(titleLarge),
    titleMedium: _axis(titleMedium),
    titleSmall: _axis(titleSmall),
    bodyLarge: _axis(bodyLarge),
    bodyMedium: _axis(bodyMedium),
    bodySmall: _axis(bodySmall),
    labelLarge: _axis(labelLarge),
    labelMedium: _axis(labelMedium),
    labelSmall: _axis(labelSmall),
  );

  /// Copies a style with its `fontWeight` mirrored onto the variable axis, and
  /// its decoration pinned off.
  ///
  /// `decoration: none` is not cosmetic. `Text` merges the ambient
  /// `DefaultTextStyle` with the style it is given, and outside a `Material`
  /// ancestor that ambient style is Flutter's debug warning — red text under a
  /// double yellow underline. A token that sets a colour but not a decoration
  /// inherits the underline and ships it. This was caught in a golden, where
  /// the figure had a solid yellow band under it.
  static TextStyle _axis(TextStyle style) => style.copyWith(
    fontVariations: _wght(
      (style.fontWeight ?? FontWeight.w400).value.toDouble(),
    ),
    decoration: TextDecoration.none,
  );
}
