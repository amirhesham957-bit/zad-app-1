/// Combo and levels of «اصطاد الكورة»: catching in a row builds a combo that
/// adds points per catch, and the level (every `catchesPerLevel` catches)
/// shortens how long a ball waits. No Flutter in here.
library;

import 'dart:math' as math;

/// One round's score keeper.
class BallRun {
  /// Catches that make a level.
  static const int catchesPerLevel = 6;

  /// Catches in a row for each step of the multiplier.
  static const int comboStep = 4;

  /// Points.
  int score = 0;

  /// Balls caught.
  int caught = 0;

  /// Caught in a row; a ball that got away resets it.
  int streak = 0;

  /// 1, then +1 for every [catchesPerLevel] catches.
  int get level => 1 + caught ~/ catchesPerLevel;

  /// Points per catch now: 1, then +1 for every [comboStep] in a row (max 4).
  int get combo => math.min(4, 1 + streak ~/ comboStep);

  /// A ball was caught; returns the points it gave.
  int hit() {
    final points = combo;
    score += points;
    caught++;
    streak++;
    return points;
  }

  /// A ball got away.
  void miss() => streak = 0;

  /// How long the next ball waits: shorter each level, never under 700 ms.
  int get ballMillis => math.max(700, 1500 - (level - 1) * 130);
}
