/// What can be spent per day for the rest of the period.
library;

/// The safe daily spend: what is spendable spread over the days that are
/// left, or all of it on the last day — Kotlin's arithmetic exactly.
double safeDailySpend({required double spendable, required int daysLeft}) =>
    daysLeft > 0 ? spendable / daysLeft : spendable;
