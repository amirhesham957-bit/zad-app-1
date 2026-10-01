// Achievements unlock from what the customer actually did: the table that
// used to mark them unlocked has had no writer since 2026-09-05.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/achievements/domain/achievements.dart';

void main() {
  test('a first price unlocks «الخطوة الأولى» with no server row', () {
    final (stats, views) = buildAchievements(
      unlocked: const <UnlockedRow>[],
      contributions: 1,
      streak: 1,
    );
    final first = views.firstWhere((v) => v.def.id == 'first_step');
    expect(first.unlocked, isTrue);
    expect(stats.unlocked, greaterThan(0));
    expect(stats.totalPoints, greaterThanOrEqualTo(first.def.points));
  });

  test('nothing done, nothing unlocked', () {
    final (stats, views) = buildAchievements(
      unlocked: const <UnlockedRow>[],
      contributions: 0,
      streak: 0,
    );
    expect(views.where((v) => v.unlocked), isEmpty);
    expect(stats.totalPoints, 0);
    expect(stats.level, 1);
    expect(stats.nextName, isNotNull);
  });

  test('a server row still counts', () {
    final (_, views) = buildAchievements(
      unlocked: const <UnlockedRow>[(achievementId: 'first_step', points: 10)],
      contributions: 0,
      streak: 0,
    );
    expect(views.firstWhere((v) => v.def.id == 'first_step').unlocked, isTrue);
  });

  test('earned points can unlock a points badge', () {
    final maxCount = kAchievementCatalog
        .where((d) => d.condition == AchievementCondition.contributionCount)
        .map((d) => d.threshold)
        .reduce((a, b) => a > b ? a : b);
    final (stats, views) = buildAchievements(
      unlocked: const <UnlockedRow>[],
      contributions: maxCount,
      streak: 30,
    );
    final scoreBadges = views.where(
      (v) => v.def.condition == AchievementCondition.totalScore,
    );
    for (final b in scoreBadges) {
      expect(
        b.unlocked,
        stats.totalPoints >= b.def.threshold,
        reason: b.def.id,
      );
    }
  });
}
