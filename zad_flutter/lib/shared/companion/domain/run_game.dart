/// The simulation behind «نطّة زادو»: an endless runner with no Flutter in it,
/// so every rule is a unit test. Zado runs on the ground, a tap jumps over a
/// crate, seeds float in the air, the pace rises slowly, one hit ends the
/// round.
///
/// World units: the view is [RunGame.width] wide, heights are measured up from
/// the ground. Score = distance (one point per [RunGame.unitsPerPoint] units)
/// + [RunGame.seedPoints] per seed — a score unit only; nothing is granted
/// (ZAD_COMPANION.md: only the server grants).
library;

import 'dart:math' as math;

/// A crate on the ground.
class RunCrate {
  /// Creates one at [x] (its left edge).
  new({required this.x, required this.w, required this.h});

  /// Left edge.
  double x;

  /// Width.
  final double w;

  /// Height.
  final double h;
}

/// A seed in the air.
class RunSeed {
  /// Creates one at [x], centred [y] above the ground.
  new({required this.x, required this.y});

  /// Centre, across.
  double x;

  /// Centre, up from the ground.
  final double y;

  /// Already picked up.
  bool taken = false;
}

/// One round.
class RunGame {
  /// Creates a round; tests pass a seeded [rng].
  new({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  /// The view's width.
  static const double width = 360;

  /// Where Zado stands across (his centre).
  static const double zadoX = 72;

  /// Zado's hit box, a little smaller than what is drawn.
  static const double zadoW = 28;

  /// Zado's hit box height.
  static const double zadoH = 36;

  /// Gravity, units per second squared.
  static const double gravity = 2200;

  /// Take-off speed of a jump.
  static const double jumpSpeed = 760;

  /// Pace at the start.
  static const double startSpeed = 220;

  /// How much the pace rises per second.
  static const double speedGain = 6;

  /// The pace never goes past this.
  static const double maxSpeed = 520;

  /// Distance that is worth one point.
  static const double unitsPerPoint = 10;

  /// What a seed is worth.
  static const int seedPoints = 25;

  /// How near a seed's centre must come to Zado's to be picked up.
  static const double pickupReach = 30;

  /// After a resume, nothing hurts for this long.
  static const double mercySeconds = 0.9;

  /// Crates, seeds.
  final List<RunCrate> crates = <RunCrate>[];

  /// The seeds.
  final List<RunSeed> seeds = <RunSeed>[];

  /// Height of Zado's feet above the ground.
  double y = 0;

  /// Vertical speed, up is positive.
  double vy = 0;

  /// Pace now.
  double speed = startSpeed;

  /// How far he has run, in units.
  double distance = 0;

  /// Seeds picked up.
  int seedCount = 0;

  /// Seconds played.
  double time = 0;

  /// The round is over.
  bool over = false;

  /// Seconds of mercy left.
  double mercy = 0;

  double _sinceSpawn = 0;
  double _gap = 260;

  /// What the round is worth now.
  int get score => (distance / unitsPerPoint).floor() + seedCount * seedPoints;

  /// On the ground.
  bool get grounded => y <= 0;

  /// A tap. Only from the ground; true when it jumped.
  bool jump() {
    if (over || !grounded) return false;
    vy = jumpSpeed;
    y = 0.001;
    return true;
  }

  /// Advances the round by [dt] seconds. Returns true when a seed was picked
  /// up in this step.
  bool step(double dt) {
    if (over || dt <= 0) return false;
    time += dt;
    if (mercy > 0) mercy = math.max(0, mercy - dt);
    speed = math.min(maxSpeed, startSpeed + speedGain * time);
    final dx = speed * dt;
    distance += dx;

    if (!grounded) {
      vy -= gravity * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
      }
    }

    for (final c in crates) {
      c.x -= dx;
    }
    for (final s in seeds) {
      s.x -= dx;
    }
    crates.removeWhere((c) => c.x + c.w < -20);
    seeds.removeWhere((s) => s.taken || s.x < -20);

    _sinceSpawn += dx;
    if (_sinceSpawn >= _gap) _spawn();

    var picked = false;
    final cy = y + zadoH / 2;
    for (final s in seeds) {
      if (s.taken) continue;
      final ddx = s.x - zadoX;
      final ddy = s.y - cy;
      if (math.sqrt(ddx * ddx + ddy * ddy) <= pickupReach) {
        s.taken = true;
        seedCount++;
        picked = true;
      }
    }

    if (mercy <= 0 && _hits()) over = true;
    return picked;
  }

  bool _hits() {
    const left = zadoX - zadoW / 2;
    const right = zadoX + zadoW / 2;
    for (final c in crates) {
      if (right > c.x && left < c.x + c.w && y < c.h) return true;
    }
    return false;
  }

  void _spawn() {
    _sinceSpawn = 0;
    // Room to land and jump again grows with the pace.
    _gap = speed * (0.8 + _rng.nextDouble() * 0.7) + 90;
    final tall = _rng.nextDouble() < 0.35;
    final crate = RunCrate(
      x: width + 40,
      w: tall ? 36 : 44,
      h: tall ? 62 : 38 + _rng.nextDouble() * 10,
    );
    crates.add(crate);
    // Seeds hang over the crate where a jump passes, or float on their own.
    if (_rng.nextDouble() < 0.75) {
      final n = 1 + _rng.nextInt(3);
      final high = 90.0 + _rng.nextInt(3) * 25;
      final from = crate.x + crate.w / 2 - (n - 1) * 15;
      for (var i = 0; i < n; i++) {
        seeds.add(RunSeed(x: from + i * 30, y: high));
      }
    }
  }

  /// «كمّل من مكانك»: the round goes on from the same score. Crates near
  /// Zado go, and a moment of mercy lets him get his feet back.
  void resume() {
    if (!over) return;
    over = false;
    y = 0;
    vy = 0;
    mercy = mercySeconds;
    crates.removeWhere((c) => c.x < width);
    _sinceSpawn = 0;
  }
}
