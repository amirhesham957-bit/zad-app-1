/// Kotlin's `LifeGoalSeeds` (`data/LifeGoalSeeds.kt`): the ready-made goals in
/// the activation step, turned into `zad_seed_life_goal`'s arguments.
///
/// Pure, so the rules the database enforces — a title of 4–200 characters, a
/// metric of at most 200, a deadline not in the past — are checked before a
/// request is sent rather than after it is refused.
///
/// The titles and metrics are **stored data** that the model reads back from
/// `agent_goals`, so they stay Arabic whatever the UI language (CLAUDE.md's
/// i18n rule). Only the button labels are UI text.
library;

/// The five choices.
enum LifeGoalPreset {
  /// أوفّر مبلغ كل شهر.
  saveMonthly,

  /// ألتزم بميزانية الشهر.
  stickToBudget,

  /// أسدد ديوني.
  payOffDebts,

  /// أقلل هدر المطبخ.
  reduceWaste,

  /// هدف تاني بكلامي.
  custom,
}

/// `zad_seed_life_goal`'s arguments.
class LifeGoalSeed {
  /// Creates a seed.
  const new({
    required this.title,
    required this.metric,
    required this.targetValue,
    required this.deadline,
  });

  /// `p_title`.
  final String title;

  /// `p_metric`.
  final String metric;

  /// `p_target_value`: the number of weekly check-ins, not an amount —
  /// `trg_agent_goal_progress` adds one per linked task that completes.
  final int targetValue;

  /// `p_deadline`, a civil date.
  final DateTime deadline;
}

/// Builds a seed, or null when the database would refuse it.
abstract final class LifeGoalSeeds {
  /// 12 weekly check-ins ≈ three months.
  static const int weeklyReviews = 12;

  /// Days until the deadline.
  static const int horizonDays = 90;

  static const int _minTitle = 4;
  static const int _maxText = 200;
  static const double _maxAmount = 100000000;

  /// Kotlin's `LifeGoalSeeds.build`.
  static LifeGoalSeed? build({
    required LifeGoalPreset preset,
    required double? amount,
    required String? customTitle,
    required DateTime today,
  }) {
    const reviews = '$weeklyReviews متابعة أسبوعية على ٣ شهور';
    final String title;
    final String metric;
    switch (preset) {
      case LifeGoalPreset.saveMonthly:
        if (amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > _maxAmount) {
          return null;
        }
        final text = amountText(amount);
        title = 'أوفّر $text كل شهر';
        metric = 'توفير $text شهريًا — $reviews';
      case LifeGoalPreset.stickToBudget:
        title = 'ألتزم بميزانية الشهر';
        metric = 'الصرف جوه الميزانية — $reviews';
      case LifeGoalPreset.payOffDebts:
        title = 'أسدد ديوني';
        metric = 'تقليل الديون المتبقية — $reviews';
      case LifeGoalPreset.reduceWaste:
        title = 'أقلل هدر المطبخ';
        metric = 'أصناف أقل بتبوظ قبل ما تتاكل — $reviews';
      case LifeGoalPreset.custom:
        final t = customTitle?.trim() ?? '';
        if (t.length < _minTitle || t.length > _maxText) return null;
        title = t;
        metric = reviews;
    }
    if (title.length > _maxText || metric.length > _maxText) return null;
    final day = DateTime(today.year, today.month, today.day);
    return LifeGoalSeed(
      title: title,
      metric: metric,
      targetValue: weeklyReviews,
      deadline: day.add(const Duration(days: horizonDays)),
    );
  }

  /// 500, not 500.0 — a whole number without decimals, otherwise two.
  static String amountText(double amount) => amount == amount.floorToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
}
