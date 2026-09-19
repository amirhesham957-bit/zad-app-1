/// The `ThemeData` the tokens add up to.
///
/// Screens should read colour and type from `Theme.of(context)` wherever
/// Material has a slot for it, so a token change lands everywhere at once. The
/// raw tokens are for the places Material has no slot: the canvas gradient, the
/// glass edge, the hero greens.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Builds the app theme.
abstract final class ZadTheme {
  /// The light theme. There is no dark theme yet; adding one means auditing
  /// every token above, not flipping a flag.
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: ZadColors.green800,
      primaryContainer: ZadColors.mint100,
      onPrimaryContainer: ZadColors.emeraldDeep,
      secondary: ZadColors.mustardOchre,
      onSecondary: Colors.white,
      tertiary: ZadColors.terracottaRust,
      onTertiary: Colors.white,
      onSurface: ZadColors.ink,
      surfaceContainerHighest: ZadColors.surfaceVariant,
      onSurfaceVariant: ZadColors.inkMuted,
      outline: ZadColors.hairline,
      error: ZadColors.terracottaRust,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ZadColors.canvasTop,
      textTheme: ZadType.textTheme.apply(
        bodyColor: ZadColors.ink,
        displayColor: ZadColors.ink,
      ),
      fontFamily: kZadArabicFont,

      // Material's ripple is the wrong feedback for this language. Presses are
      // answered with a scale and a haptic (see ZadPressable), which is what
      // iOS
      // does and what a squircle card can express without a spreading circle
      // fighting its corners.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      cardTheme: CardThemeData(
        color: ZadColors.surface,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ZadColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: zadSquircle(ZadRadii.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZadColors.ink,
        contentTextStyle: ZadType.bodyMedium.copyWith(color: Colors.white),
        shape: zadSquircle(ZadRadii.chip),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
