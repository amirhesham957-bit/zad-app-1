/// The simulation behind «زادو بيرتّب»: a 4x4 board of seeds with levels
/// (1, 2, 3...). Slide the board; two equal seeds that meet merge into the
/// next level and score its value. Over when nothing can move. No Flutter in
/// here.
///
/// The daily puzzle: [SortGame.daily] seeds the random generator from the
/// market day, so everyone starts the same board that day and the same moves
/// bring the same tiles.
library;

import 'dart:math' as math;

/// A slide.
enum SortMove {
  /// Towards the left edge.
  left,

  /// Towards the right edge.
  right,

  /// Towards the top.
  up,

  /// Towards the bottom.
  down,
}

/// One round.
class SortGame {
  /// A round with [rng].
  new({math.Random? rng}) : _rng = rng ?? math.Random() {
    _spawn();
    _spawn();
  }

  /// The puzzle of the market [day] (`yyyy-MM-dd`).
  factory daily(String day) => SortGame(
    rng: math.Random(day.codeUnits.fold<int>(17, (a, c) => a * 31 + c)),
  );

  final math.Random _rng;

  /// Board side.
  static const int size = 4;

  /// `grid[row][col]`: 0 is empty, n is level n (worth `2^n`).
  final List<List<int>> grid = List<List<int>>.generate(
    size,
    (_) => List<int>.filled(size, 0),
  );

  /// Points.
  int score = 0;

  /// Moves made.
  int moves = 0;

  /// The highest level on the board.
  int get top => grid.expand<int>((r) => r).fold<int>(0, math.max);

  /// What level [level] is worth.
  static int valueOf(int level) => level <= 0 ? 0 : 1 << level;

  /// Nothing can move.
  bool get over => !canMove;

  /// Some slide would change the board.
  bool get canMove => SortMove.values.any((m) => _slid(m).changed);

  /// Slides; returns false (and changes nothing) when nothing would move.
  bool move(SortMove m) {
    final r = _slid(m);
    if (!r.changed) return false;
    for (var i = 0; i < size; i++) {
      grid[i].setAll(0, r.grid[i]);
    }
    score += r.gained;
    moves++;
    _spawn();
    return true;
  }

  ({List<List<int>> grid, int gained, bool changed}) _slid(SortMove m) {
    final out = List<List<int>>.generate(
      size,
      (_) => List<int>.filled(size, 0),
    );
    var gained = 0;
    var changed = false;
    for (var line = 0; line < size; line++) {
      final cells = <int>[];
      for (var k = 0; k < size; k++) {
        cells.add(_at(m, line, k));
      }
      final packed = cells.where((v) => v != 0).toList();
      final merged = <int>[];
      for (var i = 0; i < packed.length; i++) {
        if (i + 1 < packed.length && packed[i] == packed[i + 1]) {
          merged.add(packed[i] + 1);
          gained += valueOf(packed[i] + 1);
          i++;
        } else {
          merged.add(packed[i]);
        }
      }
      while (merged.length < size) {
        merged.add(0);
      }
      for (var k = 0; k < size; k++) {
        if (merged[k] != cells[k]) changed = true;
        _put(out, m, line, k, merged[k]);
      }
    }
    return (grid: out, gained: gained, changed: changed);
  }

  // Cell k of line `line`, counted from the edge the board slides towards.
  int _at(SortMove m, int line, int k) => switch (m) {
    SortMove.left => grid[line][k],
    SortMove.right => grid[line][size - 1 - k],
    SortMove.up => grid[k][line],
    SortMove.down => grid[size - 1 - k][line],
  };

  void _put(List<List<int>> g, SortMove m, int line, int k, int v) {
    switch (m) {
      case SortMove.left:
        g[line][k] = v;
      case SortMove.right:
        g[line][size - 1 - k] = v;
      case SortMove.up:
        g[k][line] = v;
      case SortMove.down:
        g[size - 1 - k][line] = v;
    }
  }

  void _spawn() {
    final free = <(int, int)>[
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++)
          if (grid[r][c] == 0) (r, c),
    ];
    if (free.isEmpty) return;
    final (r, c) = free[_rng.nextInt(free.length)];
    grid[r][c] = _rng.nextDouble() < 0.85 ? 1 : 2;
  }
}
