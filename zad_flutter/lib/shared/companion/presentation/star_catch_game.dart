/// «اصطاد النجوم»: stars fall at night, رفيق زاد slides along the ground and
/// catches them. Three lives, a combo for catches in a row, the pace rises.
/// Same challenge loop as the other games (`GameRound`, `GameEndCard`).
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
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/star_game.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_end_card.dart';
import 'package:zad/shared/companion/presentation/game_hud.dart';
import 'package:zad/shared/companion/presentation/game_loop.dart';
import 'package:zad/shared/companion/presentation/game_pause.dart';
import 'package:zad/shared/companion/presentation/star_field.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Opens the game.
Future<int?> showStarCatchGame(BuildContext context, {required String name}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => StarCatchGame(name: name),
      ),
    );

/// The game's screen.
class StarCatchGame extends ConsumerStatefulWidget {
  /// Creates it.
  const new({required this.name, this.rng, super.key});

  /// The pet's name.
  final String name;

  /// Where the stars fall; tests pass a seeded one.
  final math.Random? rng;

  @override
  ConsumerState<StarCatchGame> createState() => _StarCatchGameState();
}

class _StarCatchGameState extends ConsumerState<StarCatchGame>
    with SingleTickerProviderStateMixin {
  late StarGame _game = StarGame(rng: widget.rng);
  late final GameLoop _loop = GameLoop(this, _step);
  late final AppLeaveWatcher _watcher;
  late GameRound _round = GameRound(ref.read, ZadGame.starCatch);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  CompanionState _mood = CompanionState.happy;
  bool _started = false;
  bool _paused = false;
  bool _newBest = false;
  int _bestBefore = 0;

  @override
  void initState() {
    super.initState();
    _watcher = AppLeaveWatcher(_pause);
    _bestBefore = ref.read(gameStatsProvider(ZadGame.starCatch.id)).best;
  }

  @override
  void dispose() {
    _watcher.dispose();
    _loop.dispose();
    _frame.dispose();
    _round.dispose();
    super.dispose();
  }

  void _step(double dt) {
    if (_game.over) return;
    if (_game.step(dt)) unawaited(HapticFeedback.selectionClick());
    if (_game.over) {
      _loop.stop();
      unawaited(HapticFeedback.mediumImpact());
      _round.end(_game.score);
      unawaited(_round.claim());
      _newBest =
          ref.read(gameStatsProvider(ZadGame.starCatch.id)).best > _bestBefore;
      playPetSound(PetSound.purr);
      setState(() => _mood = CompanionState.sad);
    } else {
      _frame.value++;
    }
  }

  void _pause() {
    if (!_started || _game.over || _paused || !_loop.running) return;
    _loop.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    setState(() => _paused = false);
    _loop.start();
  }

  void _drag(double dx, double scale) {
    if (_game.over || _paused) return;
    if (!_started) {
      _started = true;
      _loop.start();
      setState(() {});
    }
    _game.moveTo(dx / scale);
    _frame.value++;
  }

  void _again() {
    unawaited(_round.claim());
    _round.dispose();
    setState(() {
      _round = GameRound(ref.read, ZadGame.starCatch);
      _game = StarGame(rng: widget.rng);
      _started = false;
      _newBest = false;
      _bestBefore = ref.read(gameStatsProvider(ZadGame.starCatch.id)).best;
      _mood = CompanionState.happy;
    });
    _frame.value++;
  }

  void _leave() {
    unawaited(_round.claim());
    Navigator.of(context).pop(_game.score);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = ref.watch(gameStatsProvider(ZadGame.starCatch.id));
    final reduce = MediaQuery.disableAnimationsOf(context);
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    return Scaffold(
      backgroundColor: ZadColors.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(l.starGameTitle),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            GameHud(
              score: () => _game.score,
              best: math.max(stats.best, _game.over ? 0 : _bestBefore),
              frame: _frame,
              scoreKey: const ValueKey<String>('star-score'),
              extra: () => Semantics(
                label: l.gameLives(_game.lives),
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var i = 0; i < StarGame.startLives; i++)
                      Icon(
                        Icons.favorite,
                        size: 18,
                        color: i < _game.lives
                            ? ZadColors.mustardOchre
                            : ZadColors.mint100,
                      ),
                    if (_game.combo > 1) ...<Widget>[
                      const SizedBox(width: ZadSpacing.sm),
                      Text(
                        l.gameCombo(_game.combo),
                        key: const ValueKey<String>('star-combo'),
                        style: ZadType.titleSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final sx = c.maxWidth / StarGame.width;
                  final sy = c.maxHeight / StarGame.height;
                  final orb = 64 * sx;
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Semantics(
                          label: l.starGameHint(widget.name),
                          child: GestureDetector(
                            key: const ValueKey<String>('star-field'),
                            behavior: HitTestBehavior.opaque,
                            onPanDown: (d) => _drag(d.localPosition.dx, sx),
                            onPanUpdate: (d) => _drag(d.localPosition.dx, sx),
                            child: CustomPaint(
                              painter: StarFieldPainter(
                                game: _game,
                                repaint: _frame,
                                twinkle: !reduce,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _frame,
                        builder: (_, _) => Positioned(
                          left: starOrbLeft(_game.zadoX, sx, orb),
                          top: StarGame.catchLine * sy - orb * 0.45,
                          width: orb,
                          height: orb,
                          child: IgnorePointer(
                            child: CompanionOrb(
                              state: _mood,
                              size: orb,
                              look: look,
                              animated: !reduce,
                            ),
                          ),
                        ),
                      ),
                      if (!_started && !_game.over)
                        Positioned(
                          left: ZadSpacing.xl,
                          right: ZadSpacing.xl,
                          top: ZadSpacing.xl,
                          child: IgnorePointer(
                            child: Text(
                              l.starGameHint(widget.name),
                              key: const ValueKey<String>('star-hint'),
                              textAlign: TextAlign.center,
                              style: ZadType.titleMedium.copyWith(
                                color: ZadColors.surface,
                              ),
                            ),
                          ),
                        ),
                      if (_paused)
                        Positioned.fill(
                          child: GamePauseOverlay(onResume: _resume),
                        ),
                      if (_game.over)
                        Positioned.fill(
                          child: GameScrim(
                            child: GameEndCard(
                              round: _round,
                              stats: stats,
                              today: ref
                                  .read(
                                    gameStatsProvider(ZadGame.starCatch.id)
                                        .notifier,
                                  )
                                  .today(),
                              title: l.starGameOver,
                              newBest: _newBest,
                              adsAllowed: ref.watch(adsAllowedProvider),
                              onAgain: _again,
                              onLeave: _leave,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
