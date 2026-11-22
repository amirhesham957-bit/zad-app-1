/// «نطّة زادو»: an endless runner with رفيق زاد (owner, 2026-11-15: the pet's
/// games have nothing to do with prices). The user's own companion runs, a
/// tap jumps a crate, seeds float in the air, the pace rises, one hit ends
/// the round. The simulation is `RunGame`; the scene is `RunPainter`.
///
/// «كمّل من مكانك» is offered once per round after a hit, behind a rewarded
/// ad the customer taps; absent when ads are not allowed (kids mode, paid
/// plan). No ad ever shows during play. Seeds come from the server after the
/// round (`GameRound`); the seeds picked up on the way are score only.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/rewarded_ads.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/run_game.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_end_card.dart';
import 'package:zad/shared/companion/presentation/game_hud.dart';
import 'package:zad/shared/companion/presentation/game_loop.dart';
import 'package:zad/shared/companion/presentation/game_pause.dart';
import 'package:zad/shared/companion/presentation/run_scene.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

/// Opens the game; resolves to the round's final score.
Future<int?> showPetRunGame(BuildContext context, {required String name}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => PetRunGame(name: name),
      ),
    );

/// The game's screen.
class PetRunGame extends ConsumerStatefulWidget {
  /// Creates it.
  const new({
    required this.name,
    this.rng,
    this.game,
    this.startedForTest = false,
    super.key,
  });

  /// The pet's name.
  final String name;

  /// Where the crates and seeds come; tests pass a seeded one.
  final math.Random? rng;

  /// A round set up by hand (screenshots); null starts a fresh one.
  final RunGame? game;

  /// Skips the «tap to start» wait (screenshots).
  final bool startedForTest;

  @override
  ConsumerState<PetRunGame> createState() => _PetRunGameState();
}

class _PetRunGameState extends ConsumerState<PetRunGame>
    with SingleTickerProviderStateMixin {
  late RunGame _game = widget.game ?? RunGame(rng: widget.rng);
  late final GameLoop _loop = GameLoop(this, _step);
  late final AppLeaveWatcher _watcher;
  late GameRound _round = GameRound(ref.read, ZadGame.zadoRun);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Timer? _moodTimer;
  CompanionState _mood = CompanionState.happy;
  bool _started = false;
  bool _paused = false;
  bool _continued = false;
  bool _watching = false;
  bool _noAd = false;
  bool _patted = false;
  bool _newBest = false;
  int _bestBefore = 0;

  GameStatsController get _stats =>
      ref.read(gameStatsProvider(ZadGame.zadoRun.id).notifier);

  @override
  void initState() {
    super.initState();
    _watcher = AppLeaveWatcher(_pause);
    _bestBefore = ref.read(gameStatsProvider(ZadGame.zadoRun.id)).best;
    if (widget.startedForTest) _begin();
  }

  @override
  void dispose() {
    _watcher.dispose();
    _moodTimer?.cancel();
    _loop.dispose();
    _frame.dispose();
    _round.dispose();
    super.dispose();
  }

  void _begin() {
    if (_started) return;
    _started = true;
    _loop.start();
  }

  void _step(double dt) {
    if (_game.over) return;
    if (_game.step(dt)) _onSeed();
    if (_game.over) {
      _onHit();
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

  void _onSeed() {
    unawaited(HapticFeedback.selectionClick());
    playPetSound(PetSound.cuteSqueak);
    _moodTimer?.cancel();
    setState(() => _mood = CompanionState.celebrating);
    _moodTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && !_game.over) setState(() => _mood = CompanionState.happy);
    });
  }

  void _onHit() {
    _loop.stop();
    unawaited(HapticFeedback.mediumImpact());
    _round.end(_game.score);
    _newBest =
        ref.read(gameStatsProvider(ZadGame.zadoRun.id)).best > _bestBefore;
    // With «كمّل» still on offer the seeds wait: the round may go on.
    if (_continued || !ref.read(adsAllowedProvider)) {
      _pat();
      unawaited(_round.claim());
    }
    setState(() => _mood = CompanionState.sad);
  }

  void _pat() {
    if (_patted) return;
    _patted = true;
    ref.read(petCareProvider.notifier).pet();
    playPetSound(PetSound.purr);
  }

  void _tap() {
    if (_game.over || _paused) return;
    if (!_started) setState(_begin);
    if (_game.jump()) unawaited(HapticFeedback.lightImpact());
    _frame.value++;
  }

  Future<void> _continue() async {
    final user = ref.read(sessionControllerProvider);
    if (_continued || _watching || user == null) return;
    setState(() {
      _watching = true;
      _noAd = false;
    });
    final outcome = await ref.read(rewardedAdsProvider).watch(userId: user);
    if (!mounted) return;
    if (outcome != RewardedOutcome.earned) {
      setState(() {
        _watching = false;
        _noAd = outcome == RewardedOutcome.unavailable;
      });
      return;
    }
    _game.resume();
    setState(() {
      _continued = true;
      _watching = false;
      _mood = CompanionState.happy;
    });
    _loop.start();
  }

  void _again() {
    _pat();
    unawaited(_round.claim());
    _round.dispose();
    setState(() {
      _round = GameRound(ref.read, ZadGame.zadoRun);
      _game = RunGame(rng: widget.rng);
      _started = false;
      _continued = false;
      _watching = false;
      _noAd = false;
      _patted = false;
      _newBest = false;
      _bestBefore = ref.read(gameStatsProvider(ZadGame.zadoRun.id)).best;
      _mood = CompanionState.happy;
    });
    _frame.value++;
  }

  void _leave() {
    _pat();
    unawaited(_round.claim());
    Navigator.of(context).pop(_game.score);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = ref.watch(gameStatsProvider(ZadGame.zadoRun.id));
    final best = math.max(stats.best, _game.over ? 0 : _bestBefore);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    final adsAllowed = ref.watch(adsAllowedProvider);
    return Scaffold(
      backgroundColor: ZadColors.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(l.runGameTitle(widget.name)),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            GameHud(
              score: () => _game.score,
              best: best,
              frame: _frame,
              scoreKey: const ValueKey<String>('run-score'),
              extra: () => RunSeedsChip(count: _game.seedCount),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RunScene(
                      game: _game,
                      frame: _frame,
                      name: widget.name,
                      mood: _mood,
                      look: look,
                      reduceMotion: reduce,
                      started: _started,
                      onTap: _tap,
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(child: GamePauseOverlay(onResume: _resume)),
                  if (_game.over)
                    Positioned.fill(
                      child: GameScrim(
                        child: GameEndCard(
                          round: _round,
                          stats: stats,
                          today: _stats.today(),
                          title: l.runGameHit(widget.name),
                          newBest: _newBest,
                          adsAllowed: adsAllowed,
                          onContinue: _continued ? null : _continue,
                          continueBusy: _watching,
                          continueNoAd: _noAd,
                          onAgain: _again,
                          onLeave: _leave,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
