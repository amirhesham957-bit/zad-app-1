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
  // ── Heritage core ────────────────────────────────────────────────────────

  /// Primary. High-trust: household health and wealth. The green card's base.
  static const Color forestEmerald = Color(0xFF1B4332);

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
  static const Color mustardOchre = Color(0xFFC68216);

  /// Tertiary. Urgent: a missed dose, a debt deadline, stock about to run out.
  static const Color terracottaRust = Color(0xFFD95726);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// The canvas, top of its gradient.
  static const Color canvasTop = Color(0xFFF8F9FA);

  /// The canvas, middle.
  static const Color canvasMid = Color(0xFFF4F6F2);

  /// The canvas, bottom.
  static const Color canvasBottom = Color(0xFFEDEFE9);

  /// A card.
  static const Color surface = Color(0xFFFFFFFF);

  /// A pill, an icon backdrop, a filled container.
  static const Color surfaceVariant = Color(0xFFEDEFE9);

  // ── Ink ──────────────────────────────────────────────────────────────────

  /// Body text and figures.
  static const Color ink = Color(0xFF0F172A);

  /// Secondary text.
  static const Color slate = Color(0xFF374151);

  /// Muted labels. 5.9:1 on the canvas — the Kotlin app has a contrast test
  /// pinning this, and a lighter grey fails it.
  static const Color inkMuted = Color(0xFF5F6258);

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

  /// The screen canvas.
  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[canvasTop, canvasMid, canvasBottom],
  );

  /// The green card. Three stops, not two: the extra deep stop is what stops a
  /// large surface reading as flat fill.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[emeraldDeep, green800, green700],
    stops: <double>[0, 0.55, 1],
  );

  /// A figure on the green card: white fading to mint, so a big number has some
  /// depth without a second colour.
  static const LinearGradient heroFigure = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFFFFF), mint100],
  );
}
