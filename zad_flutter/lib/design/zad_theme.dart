/// The `ThemeData` the tokens add up to — Kotlin's `AppTheme` (`Theme.kt`)
/// with `ZadColorScheme` / `ZadDarkColorScheme` (`ZadTheme.kt`).
///
/// Like Kotlin, the app follows the system setting (`isSystemInDarkTheme()`);
/// there is no in-app toggle.
///
/// The schemes set every slot Kotlin sets, with the same value. The slots
/// Kotlin leaves unset are filled with what Compose Material3 1.3.0 (the
/// version the Kotlin BOM `2024.09.00` resolves) fills them with — read from
/// the library's own `ColorLightTokens`/`ColorDarkTokens`, not remembered.
/// They matter: a Kotlin `AlertDialog` with no `containerColor` is drawn in
/// `surfaceContainerHigh` (#ECE6F0), a snackbar in `inverseSurface`, and
/// Flutter's Material 3 components read the same slots.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_palette.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Builds the app theme.
abstract final class ZadTheme {
  /// Kotlin's `ZadColorScheme`.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: ZadPalette.forestEmerald,
    onPrimary: ZadPalette.onAccent,
    primaryContainer: ZadPalette.emeraldContainer,
    onPrimaryContainer: ZadPalette.forestEmerald,
    secondary: ZadPalette.mustardOchre,
    onSecondary: ZadPalette.onAccent,
    secondaryContainer: ZadPalette.mustardContainer,
    onSecondaryContainer: ZadPalette.mustardDark,
    tertiary: ZadPalette.terracottaRust,
    onTertiary: ZadPalette.onAccent,
    tertiaryContainer: ZadPalette.terracottaContainer,
    onTertiaryContainer: ZadPalette.terracottaDark,
    surface: ZadPalette.iosSurface,
    onSurface: ZadPalette.neutralDark,
    // Kotlin's `surfaceVariant`. Flutter renamed the slot.
    surfaceContainerHighest: ZadPalette.iosSurfaceVariant,
    onSurfaceVariant: ZadPalette.neutralMuted,
    outline: ZadPalette.iosOutline,
    outlineVariant: ZadPalette.outlineVariant,
    error: ZadPalette.terracottaRust,
    onError: ZadPalette.onAccent,
    errorContainer: ZadPalette.terracottaContainer,
    onErrorContainer: ZadPalette.terracottaDark,
    // Unset in Kotlin — Compose M3 1.3.0 baseline.
    surfaceTint: ZadPalette.forestEmerald,
    inversePrimary: Color(0xFFD0BCFF),
    inverseSurface: Color(0xFF322F35),
    onInverseSurface: Color(0xFFF5EFF7),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
    surfaceBright: Color(0xFFFEF7FF),
    surfaceDim: Color(0xFFDED8E1),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainer: Color(0xFFF3EDF7),
    surfaceContainerHigh: Color(0xFFECE6F0),
  );

  /// Kotlin's `ZadDarkColorScheme`.
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: ZadPalette.emeraldOnDark,
    onPrimary: ZadPalette.onAccentDark,
    primaryContainer: ZadPalette.emeraldContainerOnDark,
    onPrimaryContainer: ZadPalette.emeraldOnDark,
    secondary: ZadPalette.mustardOnDark,
    onSecondary: ZadPalette.onAccentDark,
    secondaryContainer: ZadPalette.mustardContainerOnDark,
    onSecondaryContainer: ZadPalette.mustardOnDark,
    tertiary: ZadPalette.terracottaOnDark,
    onTertiary: ZadPalette.onAccentDark,
    tertiaryContainer: ZadPalette.terracottaContainerOnDark,
    onTertiaryContainer: ZadPalette.terracottaOnDark,
    surface: ZadPalette.iosSurfaceDark,
    onSurface: ZadPalette.neutralOnDark,
    surfaceContainerHighest: ZadPalette.iosSurfaceVariantDark,
    onSurfaceVariant: ZadPalette.neutralMutedOnDark,
    outline: ZadPalette.iosOutlineDark,
    outlineVariant: ZadPalette.iosOutlineDark,
    error: ZadPalette.terracottaOnDark,
    onError: ZadPalette.onAccentDark,
    errorContainer: ZadPalette.terracottaContainerOnDark,
    onErrorContainer: ZadPalette.terracottaOnDark,
    // Unset in Kotlin — Compose M3 1.3.0 baseline.
    surfaceTint: ZadPalette.emeraldOnDark,
    inversePrimary: Color(0xFF6750A4),
    inverseSurface: Color(0xFFE6E0E9),
    onInverseSurface: Color(0xFF322F35),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
    surfaceBright: Color(0xFF3B383E),
    surfaceDim: Color(0xFF141218),
    surfaceContainerLowest: Color(0xFF0F0D13),
    surfaceContainerLow: Color(0xFF1D1B20),
    surfaceContainer: Color(0xFF211F26),
    surfaceContainerHigh: Color(0xFF2B2930),
  );

  /// Kotlin's `colorScheme.background`, which Flutter's scheme no longer
  /// carries. The scaffold is painted with it.
  static Color backgroundOf(Brightness brightness) =>
      brightness == Brightness.dark
      ? ZadPalette.iosBackgroundDark
      : ZadPalette.iosBackground;

  /// The light theme.
  static ThemeData light() =>
      _build(lightScheme, ZadExtendedColors.light, ZadPalette.iosBackground);

  /// The dark theme.
  static ThemeData dark() =>
      _build(darkScheme, ZadExtendedColors.dark, ZadPalette.iosBackgroundDark);

  static ThemeData _build(
    ColorScheme scheme,
    ZadExtendedColors ext,
    Color background,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[ext],
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: ZadType.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      fontFamily: kZadArabicFont,

      // Material's ripple is the wrong feedback for this language. Presses are
      // answered with a scale and a haptic (see ZadPressable), which is what
      // iOS does and what a squircle card can express without a spreading
      // circle fighting its corners.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: zadSquircle(ZadRadii.card),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: ZadColors.hairline,
        thickness: 0.5,
        space: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(kZadMinTapTarget + 8),
          shape: zadSquircle(ZadRadii.chip),
          textStyle: ZadType.labelLarge,
        ),
      ),
      // Kotlin's sheets pass `containerColor = surface` (13 of 14).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: zadSquircle(ZadRadii.sheet),
        showDragHandle: true,
      ),
      // Compose's snackbar default: inverseSurface / inverseOnSurface.
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: ZadType.bodyMedium.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: zadSquircle(ZadRadii.chip),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
