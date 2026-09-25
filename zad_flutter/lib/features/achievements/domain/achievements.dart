/// Kotlin's achievements logic (`AchievementsScreen.kt`): the fixed catalogue
/// from `zad-market-intelligence/gamification.ts`, unlocked state from real
/// `user_achievements` rows, and progress from the user's crowdsourced
/// `price_index` rows. Nothing is computed as unlocked here.
library;

/// What unlocks an achievement.
enum AchievementCondition {
  /// Prices contributed.
  contributionCount,

  /// Consecutive days.
  streak,

  /// Points earned.
  totalScore,
}

/// One catalogue entry.
typedef AchievementDef = ({
  String id,
  String name,
  String description,
  String icon,
  int points,
  AchievementCondition condition,
  int threshold,
});

/// The same catalogue as `gamification.ts`'s `ACHIEVEMENTS`.
const List<AchievementDef> kAchievementCatalog = <AchievementDef>[
  (
    id: 'first_step',
    name: 'الخطوة الأولى',
    description: 'أضف سعرك الأول',
    icon: '🌟',
    points: 10,
    condition: AchievementCondition.contributionCount,
    threshold: 1,
  ),
  (
    id: 'rising_star',
    name: 'نجم صاعد',
    description: 'أضف 10 أسعار',
    icon: '⭐',
    points: 50,
    condition: AchievementCondition.contributionCount,
    threshold: 10,
  ),
  (
    id: 'market_analyst',
    name: 'محلل أسواق',
    description: 'أضف 50 سعر',
    icon: '📊',
    points: 200,
    condition: AchievementCondition.contributionCount,
    threshold: 50,
  ),
  (
    id: 'expert_reporter',
    name: 'خبير التقارير',
    description: 'أضف 100 سعر',
    icon: '🏆',
    points: 500,
    condition: AchievementCondition.contributionCount,
    threshold: 100,
  ),
  (
    id: 'on_fire',
    name: 'أسبوع متتالي',
    description: 'ساهم 7 أيام متتالية',
    icon: '🔥',
    points: 100,
    condition: AchievementCondition.streak,
    threshold: 7,
  ),
  (
    id: 'consistency',
    name: 'الصبر والمثابرة',
    description: 'مجموع 500 نقطة',
    icon: '💪',
    points: 150,
    condition: AchievementCondition.totalScore,
    threshold: 500,
  ),
];

/// One real `user_achievements` row.
typedef UnlockedRow = ({String achievementId, int points});

/// One achievement as shown.
typedef AchievementView = ({AchievementDef def, bool unlocked});

/// The header figures.
typedef AchievementStats = ({
  int level,
  int totalPoints,
  int contributions,
  int streak,
  int unlocked,
  String? nextName,
  String? nextProgress,
});

/// `calculateStreak` from `gamification.ts`, literally: 1 when the last
/// contribution is within a day, else 0 — its limitation, kept as is.
int contributionStreak(DateTime? last, DateTime now) {
  if (last == null) return 0;
  final days = (now.difference(last).inMilliseconds / 86400000).ceil();
  return days > 1 ? 0 : 1;
}

/// Kotlin's `buildAchievementsUiState`.
(AchievementStats, List<AchievementView>) buildAchievements({
  required List<UnlockedRow> unlocked,
  required int contributions,
  required int streak,
}) {
  final ids = {for (final r in unlocked) r.achievementId};
  final total = unlocked.fold<int>(0, (sum, r) => sum + r.points);

  bool met(AchievementDef d) => switch (d.condition) {
    AchievementCondition.contributionCount => contributions >= d.threshold,
    AchievementCondition.streak => streak >= d.threshold,
    AchievementCondition.totalScore => total >= d.threshold,
  };

  // Kotlin's minByOrNull: the first entry with the smallest threshold.
  AchievementDef? next;
  for (final d in kAchievementCatalog) {
    if (ids.contains(d.id) || met(d)) continue;
    if (next == null || d.threshold < next.threshold) next = d;
  }

  final progress = next == null
      ? null
      : switch (next.condition) {
          AchievementCondition.contributionCount =>
            '$contributions/${next.threshold} مساهمة',
          AchievementCondition.streak =>
            '$streak/${next.threshold} أيام متتالية',
          AchievementCondition.totalScore => '$total/${next.threshold} نقطة',
        };

  return (
    (
      level: total ~/ 100 + 1,
      totalPoints: total,
      contributions: contributions,
      streak: streak,
      unlocked: unlocked.length,
      nextName: next?.name,
      nextProgress: progress,
    ),
    <AchievementView>[
      for (final d in kAchievementCatalog)
        (def: d, unlocked: ids.contains(d.id)),
    ],
  );
}
