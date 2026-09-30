/// Kotlin's raw palette (`ui/theme/Color.kt`), name for name and hex for hex.
///
/// These are the fixed values: they never vary by theme. The theme-aware
/// tokens — what Kotlin reads through `MaterialTheme.colorScheme` and
/// `LocalZadExtendedColors` — are built *from* these in `zad_theme.dart` and
/// `zad_extended_colors.dart`, the same way `ZadTheme.kt` builds its schemes.
///
/// A screen copied from Kotlin that names one of these directly (a category
/// pastel, a brand colour, the Sci-Fi dashboard, the voice sheet) uses the
/// same name here, without the `Zad` prefix: `ZadSciFiBg` is
/// `ZadPalette.sciFiBg`. Kids Mode, the category pastels and the brand colours
/// stay static in both themes, exactly as in Kotlin.
library;

// Each member carries its Kotlin name, and Kotlin's file documents it; a
// second copy of those comments here would only drift.
// ignore_for_file: public_member_api_docs

import 'package:flutter/painting.dart';

/// The raw palette.
abstract final class ZadPalette {
  // ── 1. Core Heritage palette ─────────────────────────────────────────────
  static const Color forestEmerald = Color(0xFF1B4332);
  static const Color forestEmeraldDark = Color(0xFF143225);
  static const Color forestEmeraldLight = Color(0xFF2D6A4F);
  static const Color emeraldContainer = Color(0xFFE8F0EC);

  static const Color mustardOchre = Color(0xFFC68216);
  static const Color mustardDark = Color(0xFFA5680E);
  static const Color mustardLight = Color(0xFFE9A844);
  static const Color mustardContainer = Color(0xFFFBF4E7);

  static const Color terracottaRust = Color(0xFFD95726);
  static const Color terracottaDark = Color(0xFFB84218);
  static const Color terracottaLight = Color(0xFFEA764B);
  static const Color terracottaContainer = Color(0xFFFDF0EA);

  // ── 2. Surfaces & iOS canvas ─────────────────────────────────────────────
  static const Color iosBackground = Color(0xFFF8F9FA);
  static const Color iosSurface = Color(0xFFFFFFFF);
  static const Color iosSurfaceVariant = Color(0xFFEDEFE9);
  static const Color iosOutline = Color(0xFFE0E3DA);
  static const Color neutralDark = Color(0xFF1F1F14);
  static const Color neutralMuted = Color(0xFF5F6258);

  // ── 3. Raw values the ColorScheme is built from ──────────────────────────
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color outlineVariant = Color(0xFFE8EBE2);

  // ── Category colours (static in both themes) ─────────────────────────────
  static const Color catBillsBg = Color(0x1AD95726);
  static const Color catBillsIcon = terracottaRust;
  static const Color catBankingBg = Color(0x1A1B4332);
  static const Color catBankingIcon = forestEmerald;
  static const Color catFoodBg = Color(0x1AC68216);
  static const Color catFoodIcon = mustardOchre;
  static const Color catTransportBg = Color(0x1A5B7065);
  static const Color catTransportIcon = Color(0xFF3F554A);
  static const Color catSavingsBg = Color(0x1A2D6A4F);
  static const Color catSavingsIcon = forestEmeraldLight;
  static const Color catDailyBg = Color(0x1AE2847A);
  static const Color catDailyIcon = Color(0xFFC0584E);
  static const Color catEntertainBg = Color(0x1A4F777E);
  static const Color catEntertainIcon = Color(0xFF2C5961);
  static const Color catHealthBg = Color(0x1A1F6E54);
  static const Color catHealthIcon = Color(0xFF135841);

  // ── Kids Mode (static on purpose — CLAUDE.md) ────────────────────────────
  static const Color kidsPrimary = Color(0xFF6B46C1);
  static const Color kidsPrimaryDark = Color(0xFF442B82);
  static const Color kidsPrimaryLight = Color(0xFFB794F4);
  static const Color kidsAccentPink = Color(0xFFED64A6);
  static const Color kidsBackground = Color(0xFF0F0A2E);
  static const Color kidsSurface = Color(0xFF1E0A4A);

  // ── 6. Dark theme raw values (ZadDarkColorScheme is built from these) ────
  static const Color emeraldOnDark = Color(0xFF74C69D);
  static const Color darkPanelBackground = forestEmeraldDark;
  static const Color darkPanelAccent = emeraldOnDark;
  static const Color darkPanelWarning = mustardLight;
  static const Color darkPanelDanger = terracottaLight;
  static const Color emeraldContainerOnDark = Color(0xFF1E4534);
  static const Color mustardOnDark = mustardLight;
  static const Color mustardContainerOnDark = Color(0xFF4A3712);
  static const Color terracottaOnDark = terracottaLight;
  static const Color terracottaContainerOnDark = Color(0xFF5A2A16);
  static const Color iosBackgroundDark = Color(0xFF10130F);
  static const Color iosSurfaceDark = Color(0xFF191D17);
  static const Color iosSurfaceVariantDark = Color(0xFF262B24);
  static const Color iosOutlineDark = Color(0xFF363C33);
  static const Color neutralOnDark = Color(0xFFE9ECE4);
  static const Color neutralMutedOnDark = Color(0xFFA6AB9C);
  static const Color onAccentDark = Color(0xFF0B1710);

  /// `primaryFixedKnowledgeMap`: the knowledge map's dark canvas in both
  /// themes. Not a general accent.
  static const Color primaryFixedKnowledgeMap = forestEmerald;

  // ── Zad Mind / Sci-Fi dashboard ──────────────────────────────────────────
  static const Color sciFiBg = Color(0xFF08090C);
  static const Color sciFiGrid = Color(0xFF111D26);
  static const Color sciFiNeonGreen = Color(0xFF00FF88);
  static const Color sciFiCyanElectric = Color(0xFF00E5FF);
  static const Color sciFiCyanSoft = Color(0xFF67E8F9);
  static const Color sciFiAmber = Color(0xFFFFB300);
  static const Color sciFiTextPrimary = Color(0xFFE2F9FF);
  static const Color sciFiTextSecondary = Color(0xFF5A7985);
  static const Color sciFiCardBg = Color(0xFF0C131B);
  static const Color sciFiBorder = Color(0xFF14202B);
  static const Color sciFiEmeraldDark = Color(0xFF042F2E);
  static const Color sciFiNodeBg = Color(0xFF0C141D);
  static const Color sciFiSheetBg = Color(0xFF0D1620);
  static const Color sciFiButtonBg = Color(0xFF17242C);

  // ── Voice & mesh gradient ────────────────────────────────────────────────
  static const Color orbMeshMint = Color(0xFF6EE7B7);
  static const Color orbMeshTeal = Color(0xFFA7F3D0);
  static const Color voiceDarkSheetBg = Color(0xF2081120);
  static const Color voiceWaveEmerald = Color(0xFF10B981);
  static const Color voiceWaveMint = Color(0xFF6EE7B7);
  static const Color voiceWaveTealDark = Color(0xFF047857);
  static const Color voiceWaveInactiveTop = Color(0xFF475569);
  static const Color voiceWaveInactiveBottom = Color(0xFF1E293B);
  static const Color voiceTextSoft = Color(0xFF94A3B8);
  static const Color voiceTextMint = Color(0xFFD1FAE5);
  static const Color voiceDangerStart = Color(0xFFF43F5E);
  static const Color voiceDangerEnd = Color(0xFF9F1239);
  static const Color voiceCyan = Color(0xFF38BDF8);
  static const Color voiceAlertAmber = Color(0xFFFBBF24);
  static const Color voiceAlertBrown = Color(0xFFB45309);

  // ── Brand & subscription services ────────────────────────────────────────
  static const Color brandNetflix = Color(0xFFE50914);
  static const Color brandShahid = Color(0xFF00A651);
  static const Color brandSpotify = Color(0xFF1DB954);
  static const Color brandYouTube = Color(0xFFFF0000);
  static const Color brandTod = Color(0xFF10B981);
  static const Color brandWatchIt = Color(0xFFFF9900);
  static const Color brandTabby = Color(0xFF29E7CD);
  static const Color brandTamara = Color(0xFFFF7043);
  static const Color brandElectricity = Color(0xFFF59E0B);
  static const Color brandWater = Color(0xFF0EA5E9);
  static const Color brandInternet = Color(0xFF3B82F6);
  static const Color brandRent = Color(0xFF8B5CF6);
  static const Color brandGold = Color(0xFFFFD700);
  static const Color brandWarning = Color(0xFFF59E0B);
  static const Color brandTelegram = Color(0xFF229ED9);

  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color mintAccent = Color(0xFF6EE7B7);
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color heartYellow = Color(0xFFFFF176);

  // ── Orb accessories (drawing colours, not UI colours) ────────────────────
  static const Color orbBowPink = Color(0xFFFF6FA5);
  static const Color orbBowPinkDeep = Color(0xFFD9467E);
  static const Color orbGlassesFrame = Color(0xFF2B2B3A);
  static const Color orbCrownGold = Color(0xFFFFC53D);
  static const Color orbCrownGoldDeep = Color(0xFFE09A12);
  static const Color orbCrownGem = Color(0xFFE5484D);
  static const Color orbFlowerPetal = Color(0xFFFFFFFF);
  static const Color orbFlowerCenter = Color(0xFFFFC53D);
  static const Color heartRed = Color(0xFFDC2626);

  // ── Companion orb states ─────────────────────────────────────────────────
  static const Color orbIdleSky = Color(0xFF34D399);
  static const Color orbIdleDeep = Color(0xFF064E3B);
  static const Color orbListeningSky = Color(0xFF00E5FF);
  static const Color orbListeningDeep = Color(0xFF0E7490);
  static const Color orbFocusedSky = Color(0xFFB388FF);
  static const Color orbFocusedDeep = Color(0xFF4A148C);
  static const Color orbSpeakingSky = Color(0xFF38BDF8);
  static const Color orbSpeakingDeep = Color(0xFF1D4ED8);
  static const Color orbHappySky = Color(0xFF7CFFB2);
  static const Color orbHappyDeep = Color(0xFF00B26A);
  static const Color orbAlertSky = Color(0xFFFF8A80);
  static const Color orbAlertDeep = Color(0xFFD32F2F);
  static const Color orbCelebratingSky = Color(0xFFFFE066);
  static const Color orbCelebratingDeep = Color(0xFFF59E0B);
  static const Color orbNeonCyan = Color(0xFF00E5FF);
  static const Color orbNeonMint = Color(0xFF6EE7B7);
  static const Color orbDeepTeal = Color(0xFF042F2E);
  static const Color orbCoreDark = Color(0xFF05181B);
  static const Color orbGlassSpecular = Color(0xFFE0F7FA);
  static const Color orbSlitGlow = Color(0xFF80DEEA);
  static const Color orbSlitCore = Color(0xFFF0FDFA);
  static const Color orbRingAura = Color(0x3300E5FF);
  static const Color orbRingOuter = Color(0x1A6EE7B7);

  // ── 3D luxury quick shortcuts ────────────────────────────────────────────
  static const List<Color> shortcutInventoryGradient = <Color>[
    Color(0xFF065F46),
    Color(0xFF059669),
    Color(0xFF34D399),
  ];
  static const Color shortcutInventoryGlow = Color(0xFF10B981);
  static const List<Color> shortcutShoppingGradient = <Color>[
    Color(0xFF9A3412),
    Color(0xFFEA580C),
    Color(0xFFFDBA74),
  ];
  static const Color shortcutShoppingGlow = Color(0xFFF97316);
  static const List<Color> shortcutFamilyGradient = <Color>[
    Color(0xFF1E40AF),
    Color(0xFF3B82F6),
    Color(0xFF93C5FD),
  ];
  static const Color shortcutFamilyGlow = Color(0xFF2563EB);
  static const List<Color> shortcutSubscriptionsGradient = <Color>[
    Color(0xFF5B21B6),
    Color(0xFF8B5CF6),
    Color(0xFFDDD6FE),
  ];
  static const Color shortcutSubscriptionsGlow = Color(0xFF7C3AED);

  // ── ZadV3 (`ui/theme/ZadV2.kt`) — static in both themes ──────────────────
  static const Color v3Green800 = Color(0xFF064E3B);
  static const Color v3Green700 = Color(0xFF0B6B4E);
  static const Color v3Green600 = Color(0xFF0F9B76);
  static const Color v3Mint100 = Color(0xFFD9F2E6);
  static const Color v3Mint50 = Color(0xFFE6F4EC);
  static const Color v3MintGlow = Color(0xFF6EE7B7);
  static const Color v3Canvas = Color(0xFFF4F6F2);
  static const Color v3Surface = Color(0xFFFFFFFF);
  static const Color v3Ink = Color(0xFF0F172A);
  static const Color v3Slate = Color(0xFF374151);
  static const Color v3Gray400 = Color(0xFF9CA3AF);
  static const Color v3Hairline = Color(0x0D000000);
  static const Color v3Warn = Color(0xFFB45309);
  static const Color v3Danger = Color(0xFFDC5B4B);
  static const Color v3Info = Color(0xFF2563EB);
  static const Color v3Violet = Color(0xFF7C3AED);
  static const Color v3AiPlate = Color(0xFF052E16);
  static const Color v3CoralLight = Color(0xFFFF8066);
  static const Color v3KidsPink = Color(0xFFEC4899);
}

/// Kotlin's `ZadSectionAccent`: one accent per section in the sections grid
/// and the "more" sheet. Content is -700 on light and -300 on dark; the
/// container is that content at 12% (light) or 18% (dark) over the surface.
enum ZadSectionAccent {
  emerald(Color(0xFF047857), Color(0xFF6EE7B7)),
  amber(Color(0xFFB45309), Color(0xFFFCD34D)),
  violet(Color(0xFF6D28D9), Color(0xFFC4B5FD)),
  blue(Color(0xFF1D4ED8), Color(0xFF93C5FD)),
  indigo(Color(0xFF4338CA), Color(0xFFA5B4FC)),
  rose(Color(0xFFBE123C), Color(0xFFFDA4AF)),
  brown(Color(0xFF92400E), Color(0xFFFDBA74)),
  green(Color(0xFF15803D), Color(0xFF86EFAC)),
  teal(Color(0xFF0F766E), Color(0xFF5EEAD4)),
  slate(Color(0xFF334155), Color(0xFFCBD5E1));

  new(this.light, this.dark);

  /// The accent on a light surface.
  final Color light;

  /// The accent on a dark surface.
  final Color dark;

  /// The icon/label colour for the active theme.
  Color content({required bool isDark}) => isDark ? dark : light;

  /// The tile behind it.
  Color container({required bool isDark}) =>
      content(isDark: isDark).withValues(alpha: isDark ? 0.18 : 0.12);
}
