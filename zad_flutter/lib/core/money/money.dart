/// Money is a `double` rounded to two decimals at every boundary, mirroring the
/// Kotlin app's `Double.asMoney()` in `data/Money.kt`. There is no minor-units
/// migration and there is not going to be one.
library;

/// Two-decimal rounding for money.
extension Money on double {
  /// Rounds to two decimals exactly the way the Kotlin app does.
  ///
  /// Kotlin uses `Math.round(this * 100) / 100.0`, and Java's `Math.round`
  /// is `floor(x + 0.5)` — half rounds **up**, toward positive infinity.
  /// Dart's own `round()` rounds half **away from zero**, so the two
  /// disagree on negative halves: `-0.005` is `0.00` here and in Kotlin,
  /// and `-0.01` under `round()`.
  ///
  /// That matters even though amounts are normally positive, because a
  /// transaction's direction lives in `is_expense` rather than in the
  /// number. A negative amount is a correction, not an impossibility, and
  /// the two clients must not disagree about one.
  double get asMoney => (this * 100 + 0.5).floorToDouble() / 100;
}
