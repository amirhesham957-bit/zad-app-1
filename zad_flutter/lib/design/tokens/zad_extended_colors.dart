/// Kotlin's `ZadExtendedColors` — the colours Material's scheme has no slot
/// for (success, info, tertiary text, the canvas stops, the agent panel, the
/// AI identity…), with the same light and dark values.
///
/// Read it with `context.zadExt`, the way Kotlin reads
/// `LocalZadExtendedColors.current`. The per-field comments in
/// `ZadExtendedColors.kt` explain each value's contrast measurement; they are
/// not repeated here so there is one place to keep them true.
library;

// Each member carries its Kotlin name, and Kotlin's file documents it; a
// second copy of those comments here would only drift.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:zad/design/tokens/zad_palette.dart';

/// Colours with no `ColorScheme` slot, per theme.
@immutable
class ZadExtendedColors extends ThemeExtension<ZadExtendedColors> {
  /// All fields, as in Kotlin's data class.
  const new({
    required this.success,
    required this.info,
    required this.textTertiary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondaryDark,
    required this.secondaryLight,
    required this.coral,
    required this.coralLight,
    required this.lilac,
    required this.canvasTop,
    required this.canvasMid,
    required this.canvasBottom,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.authWashWarm,
    required this.authWashCool,
    required this.agentPanelStart,
    required this.agentPanelEnd,
    required this.agentPanelSuccess,
    required this.agentPanelWarning,
    required this.agentPanelInfo,
    required this.agentPanelBrand,
    required this.alertBannerContainer,
    required this.onAlertBanner,
    required this.aiAccent,
    required this.aiAccentEnd,
    required this.onAiAccent,
    required this.aiAccentSoft,
    required this.aiNarrativeContainer,
    required this.onAiNarrative,
    required this.scoreGood,
    required this.onStatusPill,
    required this.chartCategorical,
    required this.textOnCardSecondary,
  });

  final Color success;
  final Color info;
  final Color textTertiary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondaryDark;
  final Color secondaryLight;
  final Color coral;
  final Color coralLight;
  final Color lilac;
  final Color canvasTop;
  final Color canvasMid;
  final Color canvasBottom;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color authWashWarm;
  final Color authWashCool;
  final Color agentPanelStart;
  final Color agentPanelEnd;
  final Color agentPanelSuccess;
  final Color agentPanelWarning;
  final Color agentPanelInfo;
  final Color agentPanelBrand;
  final Color alertBannerContainer;
  final Color onAlertBanner;
  final Color aiAccent;
  final Color aiAccentEnd;
  final Color onAiAccent;
  final Color aiAccentSoft;
  final Color aiNarrativeContainer;
  final Color onAiNarrative;
  final Color scoreGood;
  final Color onStatusPill;
  final List<Color> chartCategorical;
  final Color textOnCardSecondary;

  /// Kotlin's `ZadExtendedColorsLight`.
  static const ZadExtendedColors light = ZadExtendedColors(
    success: Color(0xFF238652),
    info: Color(0xFF2B6CB0),
    textTertiary: Color(0xFF6E7065),
    primaryDark: ZadPalette.forestEmeraldDark,
    primaryLight: ZadPalette.forestEmeraldLight,
    secondaryDark: ZadPalette.mustardDark,
    secondaryLight: ZadPalette.mustardLight,
    coral: ZadPalette.terracottaRust,
    coralLight: ZadPalette.terracottaContainer,
    lilac: Color(0xFF7C6F93),
    canvasTop: Color(0xFFF8F9FA),
    canvasMid: Color(0xFFF4F6F2),
    canvasBottom: Color(0xFFEDEFE9),
    surfaceContainerLow: Color(0xFFFBFBFA),
    surfaceContainer: ZadPalette.iosBackground,
    surfaceContainerHigh: ZadPalette.iosSurfaceVariant,
    authWashWarm: Color(0xFFFCD3C7),
    authWashCool: Color(0xFFBFE3D1),
    agentPanelStart: Color(0xFF052E16),
    agentPanelEnd: Color(0xFF0A382C),
    agentPanelSuccess: Color(0xFF4FBF87),
    agentPanelWarning: ZadPalette.mustardLight,
    agentPanelInfo: Color(0xFF7FB3E8),
    agentPanelBrand: Color(0xFF95D9B5),
    alertBannerContainer: Color(0xFFFDECEA),
    onAlertBanner: ZadPalette.terracottaDark,
    aiAccent: Color(0xFF9333EA),
    aiAccentEnd: Color(0xFF6C63FF),
    onAiAccent: Color(0xFFFFFFFF),
    aiAccentSoft: Color(0xFFC084FC),
    aiNarrativeContainer: Color(0xFFF5F3FF),
    onAiNarrative: Color(0xFF4C1D95),
    scoreGood: Color(0xFF4D7C0F),
    onStatusPill: Color(0xFFA63F1B),
    chartCategorical: <Color>[
      Color(0xFF0F9B76),
      Color(0xFF2563EB),
      Color(0xFFB45309),
      Color(0xFFDC5B4B),
      Color(0xFF7C3AED),
    ],
    textOnCardSecondary: Color(0xFF374151),
  );

  /// Kotlin's `ZadExtendedColorsDark`.
  static const ZadExtendedColors dark = ZadExtendedColors(
    success: Color(0xFF4FBF87),
    info: Color(0xFF7FB3E8),
    textTertiary: Color(0xFF8E9388),
    primaryDark: Color(0xFF3E8F68),
    primaryLight: Color(0xFF95D9B5),
    secondaryDark: Color(0xFFC08A2C),
    secondaryLight: Color(0xFFF3C476),
    coral: ZadPalette.terracottaLight,
    coralLight: Color(0xFF5A2A16),
    lilac: Color(0xFFB9A9D4),
    canvasTop: Color(0xFF10130F),
    canvasMid: Color(0xFF141712),
    canvasBottom: Color(0xFF191D17),
    surfaceContainerLow: Color(0xFF151813),
    surfaceContainer: ZadPalette.iosSurfaceDark,
    surfaceContainerHigh: Color(0xFF22261F),
    authWashWarm: Color(0xFF3A1E16),
    authWashCool: Color(0xFF14302A),
    agentPanelStart: Color(0xFF052E16),
    agentPanelEnd: Color(0xFF0A382C),
    agentPanelSuccess: Color(0xFF4FBF87),
    agentPanelWarning: ZadPalette.mustardLight,
    agentPanelInfo: Color(0xFF7FB3E8),
    agentPanelBrand: Color(0xFF95D9B5),
    alertBannerContainer: Color(0xFF3A1E16),
    onAlertBanner: ZadPalette.terracottaOnDark,
    aiAccent: Color(0xFFC084FC),
    aiAccentEnd: Color(0xFF6C63FF),
    onAiAccent: Color(0xFF1E0B36),
    aiAccentSoft: Color(0xFFC084FC),
    aiNarrativeContainer: Color(0xFF261B3D),
    onAiNarrative: Color(0xFFDDD0FB),
    scoreGood: Color(0xFFA3E635),
    onStatusPill: Color(0xFFEA764B),
    chartCategorical: <Color>[
      Color(0xFF34D399),
      Color(0xFF60A5FA),
      Color(0xFFE9A844),
      Color(0xFFF08A7A),
      Color(0xFFA78BFA),
    ],
    textOnCardSecondary: Color(0xFFB9BDB3),
  );

  @override
  ZadExtendedColors copyWith() => this;

  /// Theme switches are a swap, not a tween — Kotlin's
  /// `staticCompositionLocalOf` swaps the whole value too.
  @override
  ZadExtendedColors lerp(ZadExtendedColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// `context.zadExt.success`, as Kotlin writes `successColor`.
extension ZadExtendedColorsContext on BuildContext {
  /// The active theme's extended colours.
  ZadExtendedColors get zadExt =>
      Theme.of(this).extension<ZadExtendedColors>() ?? ZadExtendedColors.light;

  /// Kotlin's `isDarkSurface()` / `isSystemInDarkTheme()` as the theme sees it.
  bool get zadIsDark => Theme.of(this).brightness == Brightness.dark;
}
