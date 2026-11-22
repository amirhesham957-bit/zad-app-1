/// What a game remembers between rounds, per account: the best score,
/// today's best round and the day streak. Days are the account's market days
/// (`yyyy-MM-dd` in its zone), never the device's.
library;

import 'package:flutter/foundation.dart';

/// The saved stats.
@immutable
class GameStats {
  /// Creates them.
  const new({
    this.best = 0,
    this.day = '',
    this.dayBest = 0,
    this.streak = 0,
    this.lastDay = '',
  });

  /// Reads the stored json; anything unreadable is a fresh start.
  factory fromJson(Object? json) {
    if (json is! Map) return const GameStats();
    int n(Object? v) => v is int && v >= 0 ? v : 0;
    String s(Object? v) => v is String ? v : '';
    return GameStats(
      best: n(json['best']),
      day: s(json['day']),
      dayBest: n(json['dayBest']),
      streak: n(json['streak']),
      lastDay: s(json['lastDay']),
    );
  }

  /// The best round ever.
  final int best;

  /// The market day [dayBest] belongs to.
  final String day;

  /// The best round on [day].
  final int dayBest;

  /// Consecutive days played, as of [lastDay].
  final int streak;

  /// The last market day a round was played.
  final String lastDay;

  /// Stored form.
  Map<String, Object> toJson() => <String, Object>{
    'best': best,
    'day': day,
    'dayBest': dayBest,
    'streak': streak,
    'lastDay': lastDay,
  };

  /// Today's progress toward the challenge.
  int challengeProgress(String today) => day == today ? dayBest : 0;

  /// Today's challenge, a round reaching [target], is met.
  bool challengeDone(String today, int target) =>
      challengeProgress(today) >= target;

  /// The streak as it stands on [today]: it lives while the last day played
  /// was today or yesterday.
  int streakOn(String today) {
    if (lastDay == today) return streak;
    if (lastDay.isNotEmpty && lastDay == previousDay(today)) return streak;
    return 0;
  }

  /// A round that ended with [score] on market day [today].
  GameStats afterRound(int score, String today) {
    final sameDay = day == today;
    final kept = streakOn(today);
    return GameStats(
      best: score > best ? score : best,
      day: today,
      dayBest: sameDay && dayBest > score ? dayBest : score,
      streak: lastDay == today ? streak : kept + 1,
      lastDay: today,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameStats &&
      other.best == best &&
      other.day == day &&
      other.dayBest == dayBest &&
      other.streak == streak &&
      other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(best, day, dayBest, streak, lastDay);
}

/// The calendar day before [day] (`yyyy-MM-dd`); empty when unreadable.
String previousDay(String day) {
  final p = day.split('-');
  if (p.length != 3) return '';
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return '';
  final before = DateTime.utc(y, m, d).subtract(const Duration(days: 1));
  return marketDayKey(before);
}

/// `yyyy-MM-dd` of a wall-clock [wall].
String marketDayKey(DateTime wall) =>
    '${wall.year.toString().padLeft(4, '0')}-'
    '${wall.month.toString().padLeft(2, '0')}-'
    '${wall.day.toString().padLeft(2, '0')}';
