import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/companion/domain/run_game.dart';

const double _dt = 1 / 60;

void main() {
  group('RunGame', () {
    test('a jump leaves the ground and lands where it started', () {
      final g = RunGame(rng: math.Random(1));
      expect(g.jump(), isTrue);
      var peak = 0.0;
      var frames = 0;
      while (!g.grounded && frames < 600) {
        g.step(_dt);
        peak = math.max(peak, g.y);
        frames++;
      }
      expect(g.grounded, isTrue);
      expect(g.y, 0);
      // v^2 / 2g, a little under it at 60 steps a second.
      expect(peak, closeTo(131, 8));
      // No double jump in the air.
      g
        ..jump()
        ..step(_dt);
      expect(g.jump(), isFalse);
    });

    test('a crate in the way ends the round; a jump clears it', () {
      final hit = RunGame(rng: math.Random(1))
        ..crates.add(RunCrate(x: RunGame.zadoX + 60, w: 44, h: 40));
      for (var i = 0; i < 200 && !hit.over; i++) {
        hit.step(_dt);
      }
      expect(hit.over, isTrue);

      final clear = RunGame(rng: math.Random(1))
        ..crates.add(RunCrate(x: RunGame.zadoX + 60, w: 44, h: 40));
      for (var i = 0; i < 40; i++) {
        if (i == 6) clear.jump();
        clear.step(_dt);
      }
      expect(clear.over, isFalse);
      expect(clear.crates.where((c) => c.x < RunGame.zadoX - 40), isNotEmpty);
    });

    test('a seed picked up adds 25 to the score', () {
      final g = RunGame(rng: math.Random(1))
        ..seeds.add(RunSeed(x: RunGame.zadoX + 5, y: 18));
      final before = g.score;
      final picked = g.step(_dt);
      expect(picked, isTrue);
      expect(g.seedCount, 1);
      expect(g.score - before, greaterThanOrEqualTo(RunGame.seedPoints));
      expect(g.seeds.where((s) => !s.taken), isEmpty);
    });

    test('the pace rises slowly and stops at the ceiling', () {
      final g = RunGame(rng: math.Random(1));
      expect(g.speed, RunGame.startSpeed);
      g.step(_dt);
      g.crates.clear();
      final early = g.speed;
      for (var i = 0; i < 600; i++) {
        g.crates.clear();
        g.step(_dt);
      }
      expect(g.speed, greaterThan(early));
      for (var i = 0; i < 6000; i++) {
        g.crates.clear();
        g.step(_dt);
      }
      expect(g.speed, RunGame.maxSpeed);
    });

    test('distance counts as score', () {
      final g = RunGame(rng: math.Random(1));
      while (g.score < 10 && !g.over) {
        g.crates.clear();
        g.step(_dt);
      }
      expect(g.score, greaterThanOrEqualTo(10));
    });

    test('the same seed plays the same round', () {
      String play() {
        final g = RunGame(rng: math.Random(7));
        for (var i = 0; i < 900 && !g.over; i++) {
          if (i % 45 == 0) g.jump();
          g.step(_dt);
        }
        return '${g.score}/${g.seedCount}/${g.over}/${g.crates.length}';
      }

      expect(play(), play());
    });

    test('resume clears the crates near Zado and keeps the score', () {
      final g = RunGame(rng: math.Random(1))
        ..crates.add(RunCrate(x: RunGame.zadoX, w: 44, h: 40))
        ..step(_dt);
      expect(g.over, isTrue);
      final score = g.score;
      g.resume();
      expect(g.over, isFalse);
      expect(g.score, score);
      expect(g.crates.where((c) => c.x < RunGame.width), isEmpty);
      // Mercy: a crate dropped on him does not end it at once.
      g.crates.add(RunCrate(x: RunGame.zadoX, w: 44, h: 40));
      g.step(_dt);
      expect(g.over, isFalse);
    });
  });

  group('GameStats', () {
    test('a first round sets best, challenge and a streak of one', () {
      final s = const GameStats().afterRound(120, '2026-11-15');
      expect(s.best, 120);
      expect(s.challengeProgress('2026-11-15'), 120);
      expect(s.challengeDone('2026-11-15', 300), isFalse);
      expect(s.streakOn('2026-11-15'), 1);
    });

    test('the challenge is met at 300 and rolls over with the day', () {
      var s = const GameStats().afterRound(320, '2026-11-15');
      expect(s.challengeDone('2026-11-15', 300), isTrue);
      s = s.afterRound(50, '2026-11-15');
      expect(s.dayBest, 320);
      expect(s.challengeProgress('2026-11-16'), 0);
      expect(s.best, 320);
    });

    test('streak: consecutive days grow, a skipped day breaks it', () {
      var s = const GameStats().afterRound(10, '2026-11-15');
      s = s.afterRound(10, '2026-11-15');
      expect(s.streakOn('2026-11-15'), 1);
      s = s.afterRound(10, '2026-11-16');
      expect(s.streakOn('2026-11-16'), 2);
      // Alive the day after, gone two days after.
      expect(s.streakOn('2026-11-17'), 2);
      expect(s.streakOn('2026-11-18'), 0);
      s = s.afterRound(10, '2026-11-18');
      expect(s.streakOn('2026-11-18'), 1);
    });

    test('month and year edges, and junk json', () {
      expect(previousDay('2026-03-01'), '2026-02-28');
      expect(previousDay('2027-01-01'), '2026-12-31');
      expect(GameStats.fromJson(null), const GameStats());
      final s = const GameStats().afterRound(7, '2026-11-15');
      expect(GameStats.fromJson(s.toJson()), s);
    });
  });
}
