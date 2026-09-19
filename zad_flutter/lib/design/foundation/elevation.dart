/// Shadows.
///
/// Material's `elevation` draws one shadow and tints the surface. iOS stacks
/// two shadows instead — a tight dark one for contact and a wide faint one for
/// distance — and that pair is what reads as a card resting on a surface rather
/// than a rectangle with a grey edge.
///
/// The literals below are the same ones the Kotlin app's ZadV3 documents, so a
/// card sits at the same height on both clients.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/design/tokens/zad_colors.dart';

/// The shadow sets.
abstract final class ZadElevation {
  /// A card at rest.
  ///
  /// `0 1px 2px rgba(15,23,42,.04)` plus `0 8px 20px rgba(15,23,42,.07)`.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: ZadColors.shadowAmbient,
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: ZadColors.shadowSpot,
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// A card under the finger. Tighter and darker: pressing something should
  /// look like pressing it *down*, so the shadow closes rather than grows.
  static const List<BoxShadow> pressed = <BoxShadow>[
    BoxShadow(
      color: ZadColors.shadowAmbient,
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(color: ZadColors.shadowSpot, offset: Offset(0, 3), blurRadius: 8),
  ];

  /// Something floating over the content: a sheet, a menu, a FAB.
  ///
  /// `0 8px 24px rgba(15,23,42,.14)`.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x240F172A), offset: Offset(0, 8), blurRadius: 24),
  ];

  /// The green card's shadow, tinted with its own green instead of neutral
  /// grey.
  ///
  /// A saturated surface casting a grey shadow looks pasted on; a shadow that
  /// carries a little of the surface's own hue looks lit by the same light.
  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(
      color: Color(0x2A064E3B),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -4,
    ),
    BoxShadow(color: Color(0x14064E3B), offset: Offset(0, 2), blurRadius: 6),
  ];
}
