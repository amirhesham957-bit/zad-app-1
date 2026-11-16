/// The simulation behind «اصطاد النجوم»: stars fall, Zado slides along the
/// bottom and catches them. A star that lands costs a life; catching in a row
/// builds a combo that multiplies the points. No Flutter in here.
library;

import 'dart:math' as math;

/// A falling star.
class FallingStar {
  /// Creates one at [x] (0..[StarGame.width]) near the top.
  new({required this.x, required this.fall});

  /// Centre, across.
  final double x;

  /// How far it has fallen, from the top.
  double fall;

  /// Caught.
  bool caught = false;
}

/// One round.
class StarGame {
  /// Creates a round; tests pass a seeded [rng].
  new({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  /// The view's width.
  static const double width = 360;

  /// The view's height.
  static const double height = 520;

  /// Zado's half width (the catching reach, a little generous).
  static const double reach = 36;

  /// How far down a star is caught or lost (Zado's head).
  static const double catchLine = height - 70;

  /// Lives at the start.
  static const int startLives = 3;

  /// Points of one star before the combo.
  static const int starPoints = 10;

  /// Fall speed at the start, units per second.
  static const double startSpeed = 130;

  /// Fall speed never goes past this.
  static const double maxSpeed = 420;

  /// Catches in a row for each step of the combo multiplier.
  static const int comboStep = 4;

  /// The stars in the air.
  final List<FallingStar> stars = <FallingStar>[];

  /// Zado's centre, across.
  double zadoX = width / 2;

  /// Lives left.
  int lives = startLives;

  /// Points.
  int score = 0;

  /// Stars caught.
  int caught = 0;

  /// Caught in a row, since the last one that landed.
  int streak = 0;

  /// Seconds played.
  double time = 0;

  /// The round is over.
  bool over = false;

  double _sinceSpawn = 0;

  /// Multiplier now: 1, then +1 for every [comboStep] catches in a row, up
  /// to 5.
  int get combo => math.min(5, 1 + streak ~/ comboStep);

  /// How fast stars fall now.
  double get speed => math.min(maxSpeed, startSpeed + 7 * time);

  /// Moves Zado to [x], kept inside the view.
  void moveTo(double x) => zadoX = x.clamp(reach / 2, width - reach / 2);

  /// Advances by [dt] seconds. Returns true when a star was caught.
  bool step(double dt) {
    if (over || dt <= 0) return false;
    time += dt;
    _sinceSpawn += dt;
    // Closer together as it speeds up.
    final every = math.max(0.45, 1.1 - time * 0.012);
    if (_sinceSpawn >= every) {
      _sinceSpawn = 0;
      stars.add(
        FallingStar(x: 20 + _rng.nextDouble() * (width - 40), fall: -10),
      );
    }
    var gotOne = false;
    for (final s in stars) {
      s.fall += speed * dt;
      if (s.caught || s.fall < catchLine) continue;
      if ((s.x - zadoX).abs() <= reach) {
        s.caught = true;
        caught++;
        streak++;
        score += starPoints * combo;
        gotOne = true;
      } else if (s.fall > catchLine + 30) {
        s.caught = true; // gone: it landed
        lives--;
        streak = 0;
        if (lives <= 0) over = true;
      }
    }
    stars.removeWhere((s) => s.caught);
    return gotOne;
  }
}
