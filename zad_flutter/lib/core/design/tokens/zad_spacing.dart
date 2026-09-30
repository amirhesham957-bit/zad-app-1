/// Spacing and radii.
///
/// Every spacing value is divisible by 4. That is not decoration: it is what
/// makes unrelated screens line up without anyone measuring. Related elements
/// sit closer together than unrelated ones — do not space a column uniformly
/// and call it rhythm.
library;

/// The spacing scale.
abstract final class ZadSpacing {
  /// 4 — between a glyph and its label.
  static const double xs = 4;

  /// 8 — inside a pill, between a row's tightly bound parts.
  static const double sm = 8;

  /// 12 — between rows of one group.
  static const double md = 12;

  /// 16 — the standard card padding, and the screen's side gutter.
  static const double lg = 16;

  /// 24 — between groups.
  static const double xl = 24;

  /// 32 — between sections.
  static const double xxl = 32;

  /// The screen's side gutter. Named separately because it is a layout
  /// contract, not a free choice: every screen uses this one.
  static const double gutter = lg;
}

/// The corner radii.
///
/// These are radii for a *squircle*, not for a circular-arc rounded rectangle —
/// see `design/foundation/squircle.dart`. The numbers come from the Kotlin
/// app's ZadV3 so a card is the same shape on both clients.
abstract final class ZadRadii {
  /// 12 — a chip, a small tile.
  static const double chip = 12;

  /// 16 — the default card.
  static const double card = 16;

  /// 20 — a larger card.
  static const double cardLarge = 20;

  /// 24 — a bottom sheet.
  static const double sheet = 24;

  /// 28 — the hero. Apple Wallet's card radius, and what the green card uses.
  static const double hero = 28;

  /// A pill. Any value past half the height reads the same.
  static const double pill = 999;
}

/// Minimum tap target, in logical pixels.
///
/// 44 is the iOS HIG figure and Material's default `IconButton` already meets
/// it. Nothing shrinks below this for the sake of density — a target that is
/// hard to hit is not denser, it is broken.
const double kZadMinTapTarget = 44;
