/// «زادو بيرتّب»: slide the board, merge equal seeds into the next level. The
/// first board of each market day is the daily puzzle — the same for
/// everyone (`SortGame.daily`); later boards are random. Over when nothing can
/// move. Same challenge loop as the other games.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/sort_game.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_end_card.dart';
import 'package:zad/shared/companion/presentation/game_hud.dart';
import 'package:zad/shared/companion/presentation/game_pause.dart';
import 'package:zad/shared/companion/presentation/sort_board.dart';

/// Opens the game.
Future<int?> showZadoSortGame(BuildContext context) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => const ZadoSortGame(),
      ),
    );

/// The game's screen.
class ZadoSortGame extends ConsumerStatefulWidget {
  /// Creates it; tests pass a seeded [rng] for a plain round.
  const new({this.rng, super.key});

  /// Where new seeds appear; null plays the daily puzzle first.
  final math.Random? rng;

  @override
  ConsumerState<ZadoSortGame> createState() => _ZadoSortGameState();
}

class _ZadoSortGameState extends ConsumerState<ZadoSortGame> {
  late SortGame _game;
  late GameRound _round = GameRound(ref.read, ZadGame.zadoSort);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  bool _daily = false;
  bool _over = false;
  bool _newBest = false;
  int _bestBefore = 0;

  GameStatsController get _stats =>
      ref.read(gameStatsProvider(ZadGame.zadoSort.id).notifier);

  @override
  void initState() {
    super.initState();
    final stats = ref.read(gameStatsProvider(ZadGame.zadoSort.id));
    _bestBefore = stats.best;
    final today = _stats.today();
    // The daily puzzle is the first board of the market day.
    _daily = widget.rng == null && stats.day != today;
    _game = _daily ? SortGame.daily(today) : SortGame(rng: widget.rng);
  }

  @override
  void dispose() {
    _frame.dispose();
    _round.dispose();
    super.dispose();
  }

  void _move(SortMove m) {
    if (_over || !_game.move(m)) return;
    unawaited(HapticFeedback.selectionClick());
    if (_game.over) {
      unawaited(HapticFeedback.mediumImpact());
      _round.end(_game.score);
      unawaited(_round.claim());
      _newBest =
          ref.read(gameStatsProvider(ZadGame.zadoSort.id)).best > _bestBefore;
      setState(() => _over = true);
    } else {
      setState(() {});
      _frame.value++;
    }
  }

  void _again() {
    unawaited(_round.claim());
    _round.dispose();
    setState(() {
      _round = GameRound(ref.read, ZadGame.zadoSort);
      _game = SortGame();
      _daily = false;
      _over = false;
      _newBest = false;
      _bestBefore = ref.read(gameStatsProvider(ZadGame.zadoSort.id)).best;
    });
  }

  void _leave() {
    // A board left halfway still counts what it scored.
    if (!_over && _game.moves > 0) {
      _round.end(_game.score);
    }
    unawaited(_round.claim());
    Navigator.of(context).pop(_game.score);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = ref.watch(gameStatsProvider(ZadGame.zadoSort.id));
    return Scaffold(
      backgroundColor: ZadColors.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(l.sortGameTitle),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            SingleChildScrollView(
              padding: const EdgeInsets.all(ZadSpacing.lg),
              child: Column(
                children: <Widget>[
                  GameHud(
                    score: () => _game.score,
                    best: math.max(stats.best, _over ? 0 : _bestBefore),
                    frame: _frame,
                    scoreKey: const ValueKey<String>('sort-score'),
                    extra: _daily
                        ? () => Text(
                            l.sortGameDaily,
                            key: const ValueKey<String>('sort-daily'),
                            style: ZadType.titleSmall.copyWith(
                              color: ZadColors.mustardOchre,
                            ),
                          )
                        : null,
                  ),
                  Text(
                    l.sortGameHint,
                    textAlign: TextAlign.center,
                    style: ZadType.bodySmall.copyWith(
                      color: ZadColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  SortBoard(game: _game, onMove: _move),
                  const SizedBox(height: ZadSpacing.lg),
                  SortArrows(onMove: _move),
                ],
              ),
            ),
            if (_over)
              Positioned.fill(
                child: GameScrim(
                  child: GameEndCard(
                    round: _round,
                    stats: stats,
                    today: _stats.today(),
                    title: l.sortGameStuck,
                    newBest: _newBest,
                    adsAllowed: ref.watch(adsAllowedProvider),
                    onAgain: _again,
                    onLeave: _leave,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
