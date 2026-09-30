/// Compose's `Modifier.shadow(elevation, shape, ambientColor, spotColor)` as
/// Flutter shadows.
///
/// Android does not draw the colours it is given at their own alpha: the
/// ambient shadow is multiplied by the theme's `ambientShadowAlpha` (0.039)
/// and the spot shadow by `spotShadowAlpha` (0.19). Skipping that is why a
/// ported "elevation 28, 18% green" shadow usually comes out five times too
/// dark. The spot shadow falls below the caster, about half the elevation
/// down; the ambient one sits under it on every side.
library;

import 'package:flutter/widgets.dart';

/// The shadows Compose would draw at [elevation] with these colours.
List<BoxShadow> composeShadow({
  required double elevation,
  required Color ambient,
  required Color spot,
}) => <BoxShadow>[
  BoxShadow(
    color: ambient.withValues(alpha: ambient.a * 0.039),
    blurRadius: elevation,
  ),
  BoxShadow(
    color: spot.withValues(alpha: spot.a * 0.19),
    offset: Offset(0, elevation / 2),
    blurRadius: elevation,
  ),
];

/// Kotlin's `zadCardShadow` (PremiumSurfaces.kt): elevation 8, slate at 10%
/// ambient and 14% spot — under every white list card.
final List<BoxShadow> kZadCardShadow = composeShadow(
  elevation: 8,
  ambient: const Color(0x1A0F172A),
  spot: const Color(0x240F172A),
);
