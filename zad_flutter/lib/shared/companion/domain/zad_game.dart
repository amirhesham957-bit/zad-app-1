/// The four games of «ألعاب زادو» and what they share: the id the server
/// knows them by (`zad_game_reward.p_game`) and today's challenge target.
library;

/// A game in the companion's corner.
enum ZadGame {
  /// «اصطاد الكورة» (`pet_ball_game.dart`).
  ball('ball', 12),

  /// «نطّة زادو».
  zadoRun('zado_run', 300),

  /// «زادو بيرتّب».
  zadoSort('zado_sort', 400),

  /// «اصطاد النجوم».
  starCatch('star_catch', 150);

  new(this.id, this._base);

  /// The id sent to the server; never rename.
  final String id;

  final int _base;

  /// Today's challenge: a score to reach in one round. It moves a little
  /// from day to day (same for everyone on the same market day) so it is not
  /// the same number forever.
  int dailyTarget(String day) {
    final sum = day.codeUnits.fold<int>(0, (a, c) => a + c);
    final step = (_base / 6).round();
    return _base + (sum % 4) * step;
  }
}

/// Days in a row that fill the weekly box.
const int weeklyBoxDays = 5;
