/// «العب معاه»: a 20-second game with رفيق زاد (owner, 2026-10-13: «لعبة
/// بسيطة او نشاطات غير الاكل»). A ball pops up somewhere in the yard; each
/// catch is a point, and a missed ball moves on. The pet cheers every
/// catch, and the game ends with a pat — joy, the same as petting it.
///
/// Like the rest of the care it grants nothing: no XP, no seeds
/// (ZAD_COMPANION.md — only the server grants those).
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
import 'package:zad/shared/companion/application/pet_care_controller.dart';
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
  int _score = 0;
  int _ball = 0;
  Offset _at = const Offset(0.5, 0.4);
  CompanionState _mood = CompanionState.happy;
  bool _over = false;

  static const List<String> _balls = <String>['⚽', '🏀', '🎾', '⭐', '🍎'];

  @override
  void initState() {
    super.initState();
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
    // Faster as the score climbs, never below 0.7s.
    final ms = math.max(700, 1500 - _score * 40);
    _next = Timer(Duration(milliseconds: ms), () {
      if (mounted && !_over) _drop();
    });
  }

  void _catch() {
    if (_over) return;
    unawaited(HapticFeedback.lightImpact());
    playPetSound(PetSound.cuteSqueak);
    setState(() {
      _score++;
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
    setState(() {
      _over = true;
      _mood = CompanionState.celebrating;
    });
  }

  String get _verdict => switch (_score) {
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
    body: SafeArea(
      child: Column(
        children: <Widget>[
          const SizedBox(height: ZadSpacing.sm),
          Text(
            'النقط: $_score',
            key: const ValueKey<String>('pet-game-score'),
            style: ZadType.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: ZadColors.forestEmerald,
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            _over ? _verdict : 'اصطاد الكورة قبل ما تهرب!',
            textAlign: TextAlign.center,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.textTertiary),
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
          if (_over)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZadSpacing.xl,
                0,
                ZadSpacing.xl,
                ZadSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('pet-game-again'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<int>(
                          fullscreenDialog: true,
                          builder: (_) => PetBallGame(name: widget.name),
                        ),
                      ),
                      child: const Text('🔁 تاني'),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () => Navigator.of(context).pop(_score),
                      child: const Text('خلصت'),
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
