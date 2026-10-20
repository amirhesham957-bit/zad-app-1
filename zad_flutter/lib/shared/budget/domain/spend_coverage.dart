/// «أنا شايف حوالي ٤٠٪ من مصروفك» (ZAD_PLAN ٣.٤): how much of the account's
/// spending Zad is likely seeing.
///
/// Nothing on the phone knows the real spending — that is the whole point.
/// What there is: the cap the customer confirmed for the cycle, how far into
/// the cycle we are, and what has been recorded so far. A cap is a ceiling,
/// not a forecast, so the honest answer is a range: the low end assumes the
/// household spends its whole cap evenly, the high end that it spends
/// [_frugalShare] of it. Both ends are rounded to tens — «حوالي», never a
/// figure that pretends to a precision it has not got (ZAD_DREAM_PLAN §٧
/// فكرة ٢: «مدى بدل رقم مزيف»).
///
/// This is a reading of the server's budget answer, not a second budget: it
/// adds no figure of its own to what `zad_budget_state()` returned.
library;

/// The share of the cap the high end assumes is spent.
const double _frugalShare = 0.75;

/// Days into the cycle before a reading means anything. On day one a single
/// coffee is "300%".
const int _minElapsedDays = 3;

/// A coverage reading, in whole percents rounded to tens.
class SpendCoverage {
  /// Creates a reading.
  const new({required this.low, required this.high});

  /// The low end: what is seen if the whole cap is being spent.
  final int low;

  /// The high end, never below [low].
  final int high;

  /// Whether nothing has been recorded this cycle.
  bool get isBlind => high == 0;

  /// Whether Zad sees about all of it.
  bool get isFull => low >= 90;

  /// «٣٠–٤٠٪», or «٤٠٪» when both ends round alike.
  String get label => low == high ? '$low٪' : '$low–$high٪'; // l10n: data
}

/// The reading, or null when there is nothing honest to say: no confirmed
/// cap, or too early in the cycle.
///
/// [daysLeft] counts today, as the server does.
SpendCoverage? spendCoverage({
  required double spent,
  required double? cap,
  required bool capConfirmed,
  required int cycleLengthDays,
  required int daysLeft,
}) {
  if (!capConfirmed || cap == null || cap <= 0 || cycleLengthDays <= 0) {
    return null;
  }
  final elapsed = (cycleLengthDays - daysLeft + 1).clamp(0, cycleLengthDays);
  if (elapsed < _minElapsedDays) return null;
  final expected = cap * elapsed / cycleLengthDays;
  final seen = spent < 0 ? 0.0 : spent;
  return SpendCoverage(
    low: _tens(seen / expected),
    high: _tens(seen / (expected * _frugalShare)),
  );
}

int _tens(double ratio) => ((ratio * 10).round() * 10).clamp(0, 100);
