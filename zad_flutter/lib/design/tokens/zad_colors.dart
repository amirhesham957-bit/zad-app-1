/// The palette, carried over from the Kotlin app's `ui/theme/Color.kt` and
/// `ZadV2.kt` rather than invented here.
///
/// The design language is "Zad Culinary & Wealth Heritage": deep forest
/// emerald, warm mustard ochre and terracotta rust over crisp iOS-light
/// surfaces. The hex values are the same ones the Android app ships, so the two
/// clients cannot drift into being two different products — and so "the green
/// card" means the same green in both.
///
/// Every value here is a raw token. Screens read them through
/// `Theme.of(context)` where Material has a slot, and through [ZadColors]
/// directly where it does not.
library;

import 'package:flutter/material.dart';

/// The raw palette.
abstract final class ZadColors {
  // Kotlin's lowercase tokens (`primary`, `onSurfaceVariant`, `surface`,
  // `successColor`…) are `@Composable get()` accessors that resolve through
  // the active theme, which is how dark mode reaches ~900 call sites that name
  // them directly. The getters below are the same idea for the Flutter call
  // sites that name these tokens: each one that mirrors a theme-aware Kotlin
  // token follows [isDark]. The rest (the V3 greens, the hero gradients, the
  // hairline, the shadows) are static in Kotlin too, and stay `const` here.
  /// Whether the dark theme is active. Set by `ZadApp` only, which then
  /// rebuilds every element, the way a Compose theme switch recomposes every
  /// reader.
  static bool isDark = false;

  // ── Heritage core ────────────────────────────────────────────────────────

  /// Primary. High-trust: household health and wealth. The green card's base.
  static Color get forestEmerald =>
      isDark ? const Color(0xFF74C69D) : const Color(0xFF1B4332);

  /// Darker primary, for the hero gradient's deep end.
  static const Color emeraldDeep = Color(0xFF0A382C);

  /// The brand green the V3 language leads with.
  static const Color green800 = Color(0xFF064E3B);

  /// Mid green.
  static const Color green700 = Color(0xFF0B6B4E);

  /// Bright green, for accents on dark.
  static const Color green600 = Color(0xFF0F9B76);

  /// Pale mint, for tints on white.
  static const Color mint100 = Color(0xFFD9F2E6);

  /// Paler mint.
  static const Color mint50 = Color(0xFFE6F4EC);

  /// The AI accent glow. This is the one that carries the Web3 feel.
  static const Color mintGlow = Color(0xFF6EE7B7);

  /// Secondary. Due dates, budget warnings, anything pending.
  static Color get mustardOchre =>
      isDark ? const Color(0xFFE9A844) : const Color(0xFFC68216);

  /// Tertiary. Urgent: a missed dose, a debt deadline, stock about to run out.
  static Color get terracottaRust =>
      isDark ? const Color(0xFFEA764B) : const Color(0xFFD95726);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// The canvas, top of its gradient.
  static Color get canvasTop =>
      isDark ? const Color(0xFF10130F) : const Color(0xFFF8F9FA);

  /// The canvas, middle.
  static Color get canvasMid =>
      isDark ? const Color(0xFF141712) : const Color(0xFFF4F6F2);

  /// The canvas, bottom.
  static Color get canvasBottom =>
      isDark ? const Color(0xFF191D17) : const Color(0xFFEDEFE9);

  /// A card.
  static Color get surface =>
      isDark ? const Color(0xFF191D17) : const Color(0xFFFFFFFF);

  /// A pill, an icon backdrop, a filled container.
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF262B24) : const Color(0xFFEDEFE9);

  // ── Ink ──────────────────────────────────────────────────────────────────

  /// Body text and figures.
  static Color get ink =>
      isDark ? const Color(0xFFE9ECE4) : const Color(0xFF1F1F14);

  /// Secondary text.
  static Color get slate =>
      isDark ? const Color(0xFFB9BDB3) : const Color(0xFF374151);

  /// Muted labels. 5.9:1 on the canvas — the Kotlin app has a contrast test
  /// pinning this, and a lighter grey fails it.
  static Color get inkMuted =>
      isDark ? const Color(0xFFA6AB9C) : const Color(0xFF5F6258);

  // ── Lines and shadows ────────────────────────────────────────────────────

  /// A hairline on white. Drawn at 0.5 logical pixels, iOS-style.
  static const Color hairline = Color(0x0D000000);

  /// The hairline that reads as a glass edge on a dark surface.
  static const Color glassEdge = Color(0x1FFFFFFF);

  /// Card shadow, the wide soft half.
  static const Color shadowSpot = Color(0x120F172A);

  /// Card shadow, the tight contact half.
  static const Color shadowAmbient = Color(0x0A0F172A);

  // ── Gradients ────────────────────────────────────────────────────────────

  /// The screen canvas — Kotlin's `ZadCanvasBackground`: straight down, with
  /// the middle stop at 45%.
  static LinearGradient get canvas => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[canvasTop, canvasMid, canvasBottom],
    stops: const <double>[0, 0.45, 1],
  );

  /// The green card. Three stops, not two: the extra deep stop is what stops a
  /// large surface reading as flat fill.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[emeraldDeep, green800, green700],
    stops: <double>[0, 0.55, 1],
  );

  /// Kotlin's `ZadWalletHeroCard` gradient, stop for stop: deep emerald, a
  /// bright green band, then down to near-black green.
  static const LinearGradient wallet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[emeraldDeep, green600, green800, Color(0xFF052E16)],
  );

  /// Kotlin's `info` — the subscriptions card's accent.
  static Color get info =>
      isDark ? const Color(0xFF7FB3E8) : const Color(0xFF2B6CB0);

  /// Kotlin's `primaryLight`, the far end of a healthy progress gradient.
  static Color get forestLight =>
      isDark ? const Color(0xFF95D9B5) : const Color(0xFF2D6A4F);

  /// Kotlin's `ZadMustardLight`, the far end of a warning gradient.
  static Color get mustardLight =>
      isDark ? const Color(0xFFF3C476) : const Color(0xFFE9A844);

  /// Kotlin's `outline`: the hairline round a glance card.
  static Color get outline =>
      isDark ? const Color(0xFF363C33) : const Color(0xFFE0E3DA);

  /// Kotlin's `outlineVariant`: a track, a neutral tile.
  static Color get outlineVariant =>
      isDark ? const Color(0xFF363C33) : const Color(0xFFE8EBE2);

  /// Kotlin's `surfaceContainerLow`: a row inside a white card.
  static Color get surfaceLow =>
      isDark ? const Color(0xFF151813) : const Color(0xFFFBFBFA);

  /// The spent chip's dot on the green card.
  static const Color spentDot = Color(0xFFF59E0B);

  /// The committed chip's dot on the green card.
  static const Color committedDot = Color(0xFFFF8066);

  /// The "confirmed" tick beside the balance.
  static const Color confirmedTick = Color(0xFF6EE7B7);

  /// A figure on the green card: white fading to mint, so a big number has some
  /// depth without a second colour.
  static const LinearGradient heroFigure = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFFFFF), mint100],
  );
}
