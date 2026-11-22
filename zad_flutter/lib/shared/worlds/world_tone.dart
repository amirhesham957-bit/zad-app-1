/// A world is light by default; a few (the brain) are dark, by the owner's
/// choice. The scaffold puts the tone in scope and the shared pieces (card,
/// links strip, header) read it, so a world's body only asks the tone for its
/// text colours.
library;

import 'package:flutter/widgets.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';

/// Light or dark.
enum ZadWorldTone {
  /// The default.
  light,

  /// A night world.
  dark;

  /// The tone in scope; light outside a world.
  static ZadWorldTone of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZadWorldToneScope>()?.tone ??
      light;

  /// Whether this is the dark tone.
  bool get isDark => this == dark;

  /// Text.
  Color get ink => isDark ? ZadWorldColors.darkInk : ZadColors.ink;

  /// Quieter text.
  Color get inkMuted =>
      isDark ? ZadWorldColors.darkInkMuted : ZadColors.inkMuted;

  /// A card's fill.
  Color get surface => isDark ? ZadWorldColors.darkSurface : ZadColors.surface;

  /// A hairline.
  Color get outline => isDark ? ZadWorldColors.darkOutline : ZadColors.outline;

  /// Accent text and icons: the world's colour on light, the glow on dark.
  Color accent(Color world) => isDark ? ZadWorldColors.darkGlow : world;
}

/// Puts a tone in scope.
class ZadWorldToneScope extends InheritedWidget {
  /// Creates the scope.
  const new({required this.tone, required super.child, super.key});

  /// The tone.
  final ZadWorldTone tone;

  @override
  bool updateShouldNotify(ZadWorldToneScope old) => old.tone != tone;
}
