import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/companion/domain/ball_run.dart';
import 'package:zad/shared/companion/domain/game_stats.dart';
import 'package:zad/shared/companion/domain/sort_game.dart';
import 'package:zad/shared/companion/domain/star_game.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';

void main() {
  group('StarGame', () {
    test('a star over Zado is caught and scores; combo grows', () {
      final g = StarGame(rng: math.Random(1))..moveTo(100);
      for (var i = 0; i < 5; i++) {
        g.stars.add(FallingStar(x: 100, fall: StarGame.catchLine - 1));
        g.step(0.05);
      }
      expect(g.caught, 5);
      expect(g.lives, StarGame.startLives);
      // The fourth in a row raised the multiplier: 10+10+10+20+20.
      expect(g.score, 70);
      expect(g.combo, 2);
    });

    test('a star that lands costs a life, resets the combo, three end it', () {
      final g = StarGame(rng: math.Random(1))..moveTo(300);
      g.stars.add(FallingStar(x: 20, fall: StarGame.catchLine + 40));
      g.step(0.016);
      expect(g.lives, 2);
      expect(g.streak, 0);
      for (var i = 0; i < 2; i++) {
        g.stars.add(FallingStar(x: 20, fall: StarGame.catchLine + 40));
        g.step(0.016);
      }
      expect(g.lives, 0);
      expect(g.over, isTrue);
      expect(g.step(0.016), isFalse);
    });

    test('it speeds up, never past the cap; Zado stays inside the view', () {
      final g = StarGame(rng: math.Random(2));
      final first = g.speed;
      g.time = 10;
      expect(g.speed, greaterThan(first));
      g.time = 1e6;
      expect(g.speed, StarGame.maxSpeed);
      g.moveTo(-50);
      expect(g.zadoX, greaterThan(0));
      g.moveTo(9999);
      expect(g.zadoX, lessThan(StarGame.width));
    });
  });

  group('SortGame', () {
    test('equal seeds merge into the next level once per slide', () {
      final g = SortGame(rng: math.Random(1));
      for (final row in g.grid) {
        row.fillRange(0, 4, 0);
      }
      g.grid[0].setAll(0, <int>[1, 1, 1, 1]);
      expect(g.move(SortMove.left), isTrue);
      expect(g.grid[0].sublist(0, 2), <int>[2, 2]);
      expect(g.score, SortGame.valueOf(2) * 2);
    });

    test('a slide that moves nothing changes nothing', () {
      final g = SortGame(rng: math.Random(1));
      for (final row in g.grid) {
        row.fillRange(0, 4, 0);
      }
      g.grid[0][0] = 3;
      final moves = g.moves;
      expect(g.move(SortMove.left), isFalse);
      expect(g.move(SortMove.up), isFalse);
      expect(g.moves, moves);
      expect(g.move(SortMove.right), isTrue);
      expect(g.grid[0][3], 3);
    });

    test('a full board with no equal neighbours is over', () {
      final g = SortGame(rng: math.Random(1));
      var v = 0;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          g.grid[r][c] = (r + c).isEven ? 1 : 2;
          v++;
        }
      }
      expect(v, 16);
      expect(g.over, isTrue);
      g.grid[0][1] = 1;
      expect(g.over, isFalse);
    });

    test('the daily puzzle is the same for a day and differs between days', () {
      String board(SortGame g) => g.grid.map((r) => r.join()).join('/');
      final a = SortGame.daily('2026-11-15');
      final b = SortGame.daily('2026-11-15');
      expect(board(a), board(b));
      a.move(SortMove.left);
      b.move(SortMove.left);
      expect(board(a), board(b));
      final boards = <String>{
        for (var d = 10; d < 20; d++) board(SortGame.daily('2026-11-$d')),
      };
      expect(boards.length, greaterThan(1));
    });
  });

  group('BallRun', () {
    test('combo and levels', () {
      final r = BallRun();
      for (var i = 0; i < 3; i++) {
        expect(r.hit(), 1);
      }
      expect(r.hit(), 1);
      expect(r.hit(), 2); // fifth in a row: combo x2
      expect(r.level, 1);
      r.hit();
      expect(r.level, 2);
      final slow = BallRun().ballMillis;
      expect(r.ballMillis, lessThan(slow));
      r.miss();
      expect(r.combo, 1);
      expect(r.hit(), 1);
    });

    test('a ball never waits less than 700 ms', () {
      final r = BallRun();
      for (var i = 0; i < 200; i++) {
        r.hit();
      }
      expect(r.ballMillis, 700);
    });
  });

  group('daily challenge', () {
    test('the target is fixed for a day, moves between days, per game', () {
      for (final g in ZadGame.values) {
        expect(g.dailyTarget('2026-11-15'), g.dailyTarget('2026-11-15'));
        final set = <int>{
          for (var d = 10; d < 20; d++) g.dailyTarget('2026-11-$d'),
        };
        expect(set.length, greaterThan(1));
      }
    });

    test('the game ids are the ones the server knows', () {
      expect(ZadGame.values.map((g) => g.id), <String>[
        'ball',
        'zado_run',
        'zado_sort',
        'star_catch',
      ]);
    });

    test('streak: yesterday keeps it, a gap loses it, the day rolls over', () {
      var s = const GameStats().afterRound(50, '2026-11-14');
      s = s.afterRound(60, '2026-11-15');
      expect(s.streakOn('2026-11-15'), 2);
      expect(s.streakOn('2026-11-16'), 2); // not lost until a day is missed
      expect(s.streakOn('2026-11-17'), 0);
      s = s.afterRound(10, '2026-11-17');
      expect(s.streak, 1);
      // Month and year edges.
      expect(previousDay('2026-12-01'), '2026-11-30');
      expect(previousDay('2027-01-01'), '2026-12-31');
      // A new day starts the challenge afresh.
      expect(s.challengeProgress('2026-11-18'), 0);
      expect(s.best, 60);
    });
  });
}
