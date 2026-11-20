/// «العب معاه»: a 20-second game with رفيق زاد (owner, 2026-10-13: «لعبة
/// بسيطة او نشاطات غير الاكل»). A ball pops up somewhere in the yard; each
/// catch is a point, and a missed ball moves on. The pet cheers every
/// catch, and the game ends with a pat — joy, the same as petting it.
///
/// Catches in a row build a combo (more points per catch) and every few
/// catches a level makes the ball wait less (`BallRun`). The round ends
/// through the games' shared loop (`GameRound`, `GameEndCard`): the server
/// grants the seeds (ZAD_COMPANION.md — only the server grants those).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/companion/application/game_round.dart';
import 'package:zad/shared/companion/application/game_stats_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/ball_run.dart';
import 'package:zad/shared/companion/domain/zad_game.dart';
import 'package:zad/shared/companion/presentation/game_end_card.dart';
import 'package:zad/shared/companion/presentation/game_pause.dart';
import 'package:zad/shared/orb/application/pet_sound.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Opens the game; resolves to the score.
Future<int?> showPetBallGame(BuildContext context, {required String name}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => PetBallGame(name: name),
      ),
    );

/// The game's screen.
class PetBallGame extends ConsumerStatefulWidget {
  /// Creates it.
  const new({required this.name, this.rng, super.key});

  /// The pet's name.
  final String name;

  /// Where the balls fall; tests pass a seeded one.
  final math.Random? rng;

  /// How long a round lasts.
  static const int seconds = 20;

  @override
  ConsumerState<PetBallGame> createState() => _PetBallGameState();
}

class _PetBallGameState extends ConsumerState<PetBallGame> {
  late final math.Random _rng = widget.rng ?? math.Random();
  Timer? _clock;
  Timer? _next;
  int _left = PetBallGame.seconds;
  final BallRun _run = BallRun();
  late final GameRound _round = GameRound(ref.read, ZadGame.ball);
  bool _newBest = false;
  int _bestBefore = 0;
  int _ball = 0;
  Offset _at = const Offset(0.5, 0.4);
  CompanionState _mood = CompanionState.happy;
  bool _over = false;

  static const List<String> _balls = <String>['⚽', '🏀', '🎾', '⭐', '🍎'];

  @override
  void initState() {
    super.initState();
    _bestBefore = ref.read(gameStatsProvider(ZadGame.ball.id)).best;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    _drop();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _next?.cancel();
    _round.dispose();
    super.dispose();
  }

  /// A new ball; it moves on by itself if not caught in time.
  void _drop() {
    _next?.cancel();
    setState(() {
      _ball++;
      _at = Offset(
        0.1 + _rng.nextDouble() * 0.8,
        0.05 + _rng.nextDouble() * 0.7,
      );
    });
    // Each level waits less, never under 0.7s.
    _next = Timer(Duration(milliseconds: _run.ballMillis), () {
      if (!mounted || _over) return;
      setState(_run.miss); // it got away: the combo starts again
      _drop();
    });
  }

  void _catch() {
    if (_over) return;
    unawaited(HapticFeedback.lightImpact());
    playPetSound(PetSound.cuteSqueak);
    setState(() {
      _run.hit();
      _mood = CompanionState.celebrating;
    });
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_over) setState(() => _mood = CompanionState.happy);
    });
    _drop();
  }

  void _end() {
    if (_over) return;
    _clock?.cancel();
    _next?.cancel();
    ref.read(petCareProvider.notifier).pet();
    playPetSound(PetSound.purr);
    _round.end(_run.score);
    unawaited(_round.claim());
    _newBest = ref.read(gameStatsProvider(ZadGame.ball.id)).best > _bestBefore;
    setState(() {
      _over = true;
      _mood = CompanionState.celebrating;
    });
  }

  String get _verdict => switch (_run.score) {
    0 => '${widget.name} مستني تلعب معاه تاني 🥺',
    < 8 => 'حلو! ${widget.name} اتبسط 😊',
    < 15 => 'برافو! ${widget.name} طاير من الفرحة 🤩',
    _ => 'أسطورة! ${widget.name} مش مصدّق 🏆',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.surface,
    appBar: AppBar(
      title: Text('العب مع ${widget.name}'),
      actions: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: ZadSpacing.lg),
            child: Text(
              '⏱ $_left',
              key: const ValueKey<String>('pet-game-clock'),
              style: ZadType.titleMedium,
            ),
          ),
        ),
      ],
    ),
    body: Stack(
      children: <Widget>[
        SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: ZadSpacing.sm),
              Text(
                'النقط: ${_run.score}',
                key: const ValueKey<String>('pet-game-score'),
                style: ZadType.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ZadColors.forestEmerald,
                ),
              ),
              Text(
                _run.combo > 1
                    ? '${context.l10n.gameLevel(_run.level)} · '
                          '${context.l10n.gameCombo(_run.combo)}'
                    : context.l10n.gameLevel(_run.level),
                key: const ValueKey<String>('pet-game-combo'),
                style: ZadType.titleSmall,
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                _over ? _verdict : 'اصطاد الكورة قبل ما تهرب!',
                textAlign: TextAlign.center,
                style: ZadType.bodyMedium.copyWith(
                  color: ZadColors.textTertiary,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
                          child: CompanionOrb(state: _mood, size: 120),
                        ),
                      ),
                      if (!_over)
                        AnimatedPositioned(
                          key: const ValueKey<String>('pet-game-ball'),
                          duration: ZadDuration.quick,
                          curve: ZadCurves.springy,
                          left: _at.dx * (c.maxWidth - 64),
                          top: _at.dy * (c.maxHeight - 200),
                          child: GestureDetector(
                            onTap: _catch,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey<int>(_ball),
                              tween: Tween<double>(begin: 0.3, end: 1),
                              duration: ZadDuration.quick,
                              curve: ZadCurves.springy,
                              builder: (_, s, child) =>
                                  Transform.scale(scale: s, child: child),
                              child: SizedBox.square(
                                dimension: 64,
                                child: Center(
                                  child: Text(
                                    _balls[_ball % _balls.length],
                                    style: ZadType.displayMedium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_over)
          Positioned.fill(
            child: GameScrim(
              child: GameEndCard(
                round: _round,
                stats: ref.watch(gameStatsProvider(ZadGame.ball.id)),
                today: ref
                    .read(gameStatsProvider(ZadGame.ball.id).notifier)
                    .today(),
                title: _verdict,
                newBest: _newBest,
                adsAllowed: ref.watch(adsAllowedProvider),
                onAgain: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<int>(
                    fullscreenDialog: true,
                    builder: (_) => PetBallGame(name: widget.name),
                  ),
                ),
                onLeave: () => Navigator.of(context).pop(_run.score),
              ),
            ),
          ),
      ],
    ),
  );
}
