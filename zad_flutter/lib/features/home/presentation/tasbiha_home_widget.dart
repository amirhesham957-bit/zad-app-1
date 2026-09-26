/// Kotlin's `TasbihaHomeWidget` (`ui/screens/HomeScreenWidgets.kt`): بستان
/// التسبيح on the adult home — the tree floating over Lottie's garden burst,
/// the progress bar to the next stage, «سبحان الله» with petals and a small
/// buzz, and the family challenge ring when one is running.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_palette.dart';
import 'package:zad/features/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/features/tasbiha/domain/tasbiha.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';

// ZadSprings.Celebrate (0.4 / 500) out, ZadSprings.Press (0.55 / 600) back.
const SpringDescription _celebrate = SpringDescription(
  mass: 1,
  stiffness: 500,
  damping: 2 * 0.4 * 22.360679774998,
);
const SpringDescription _press = SpringDescription(
  mass: 1,
  stiffness: 600,
  damping: 2 * 0.55 * 24.494897427832,
);

/// The widget, with Kotlin's `AppearOnEntry` gap below it.
class TasbihaHomeSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<TasbihaHomeSlot> createState() => _TasbihaHomeSlotState();
}

class _TasbihaHomeSlotState extends ConsumerState<TasbihaHomeSlot> {
  @override
  void initState() {
    super.initState();
    // Kotlin's FamilyViewModel reads the tree when home opens.
    unawaited(
      Future<void>.microtask(() {
        if (!mounted) return;
        if (ref.read(tasbihaControllerProvider).myTrees.isEmpty) {
          unawaited(ref.read(tasbihaControllerProvider.notifier).load());
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tasbihaControllerProvider);
    final challenge = view.challenges.firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TasbihaHomeWidget(
        tree: view.myTrees.firstOrNull,
        onTasbih: () => ref.read(tasbihaControllerProvider.notifier).tap(),
        onOpen: () => unawaited(showTasbihaScreen(context)),
        activeChallenge: challenge,
        challengeClicks: challenge == null
            ? 0
            : view.progress[challenge.id] ?? 0,
      ),
    );
  }
}

/// The card.
class TasbihaHomeWidget extends StatefulWidget {
  /// Creates the card.
  const new({
    required this.tree,
    required this.onTasbih,
    required this.onOpen,
    this.activeChallenge,
    this.challengeClicks = 0,
    super.key,
  });

  /// The member's tree, or null before it is read.
  final GardenTree? tree;

  /// «سبحان الله».
  final VoidCallback onTasbih;

  /// Opens the garden.
  final VoidCallback onOpen;

  /// The family challenge, when one is running.
  final TasbihaChallenge? activeChallenge;

  /// The family's clicks on it.
  final int challengeClicks;

  @override
  State<TasbihaHomeWidget> createState() => _TasbihaHomeWidgetState();
}

class _TasbihaHomeWidgetState extends State<TasbihaHomeWidget>
    with TickerProviderStateMixin {
  // floatY from the prototype: 8 px up and down, 1.7 s each way.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);
  late final AnimationController _tapScale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _petals = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _confetti = false;
  late int _lastLevel = widget.tree?.level ?? 1;

  @override
  void didUpdateWidget(TasbihaHomeWidget old) {
    super.didUpdateWidget(old);
    final level = widget.tree?.level ?? 1;
    if (level > _lastLevel) {
      setState(() => _confetti = true);
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _confetti = false);
      });
    }
    _lastLevel = level;
  }

  @override
  void dispose() {
    _float.dispose();
    _tapScale.dispose();
    _petals.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    // The prototype's tapTasbih: a 12 ms buzz and a burst of petals.
    unawaited(HapticFeedback.selectionClick());
    _petals.forward(from: 0);
    widget.onTasbih();
    await _tapScale.animateWith(
      SpringSimulation(_celebrate, _tapScale.value, 1.22, 0),
    );
    if (!mounted) return;
    await _tapScale.animateWith(
      SpringSimulation(_press, _tapScale.value, 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final tree = widget.tree;
    final progress = (tree?.progressToNext() ?? 0).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt().clamp(0, 100);
    final next = tree?.nextLevelAt();
    final goal = next != null && next != 1 << 31 ? next : (tree?.score ?? 0);

    return ZadPressable(
      scale: 0.98,
      onPressed: widget.onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            // GlassCard: a 14 dp blur behind 78% white, a 5% black hairline.
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8.6, sigmaY: 8.6),
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.78)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.park, size: 18, color: ext.secondaryDark),
                      const SizedBox(width: 6),
                      Text(
                        'بستان التسبيح',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ext.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: ext.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Lottie.asset(
                            'assets/lottie/zad_v4_garden_burst.json',
                            width: 96,
                            height: 96,
                          ),
                          AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[
                              _float,
                              _tapScale,
                            ]),
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                -8 *
                                    Curves.fastOutSlowIn.transform(
                                      _float.value,
                                    ),
                              ),
                              child: Transform.scale(
                                scale: _tapScale.value,
                                child: child,
                              ),
                            ),
                            child: Text(
                              tree?.stageEmoji() ?? '🌰',
                              style: const TextStyle(fontSize: 50),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _petals,
                            builder: (context, _) {
                              if (!_petals.isAnimating) {
                                return const SizedBox.shrink();
                              }
                              final t = Curves.linearToEaseOut.transform(
                                _petals.value,
                              );
                              return Transform.translate(
                                // Kotlin's -140f is in pixels, not dp.
                                offset: Offset(
                                  0,
                                  -140 /
                                      MediaQuery.devicePixelRatioOf(context) *
                                      t,
                                ),
                                child: Opacity(
                                  opacity: 1 - t,
                                  child: const _EmojiRow(<String>[
                                    '🍃',
                                    '🌸',
                                    '🍃',
                                    '🌸',
                                  ]),
                                ),
                              );
                            },
                          ),
                          if (_confetti) ...<Widget>[
                            const _EmojiRow(<String>[
                              '🌸',
                              '🍃',
                              '🌸',
                              '🍃',
                              '🌸',
                            ]),
                            Lottie.asset(
                              'assets/lottie/lottie_confetti_burst.json',
                              width: 140,
                              height: 140,
                              repeat: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: progress),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (context, value, _) =>
                                FractionallySizedBox(
                                  alignment: AlignmentDirectional.centerStart,
                                  widthFactor: value.clamp(0.0, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          ZadPalette.kidsPrimary,
                                          ext.primaryLight,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        '${tree?.score ?? 0} / $goal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      ZadPressable(
                        scale: 0.96,
                        onPressed: _tap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                ZadPalette.kidsPrimary,
                                Color(0xFF9333EA),
                              ],
                            ),
                          ),
                          child: const Text(
                            'سبحان الله',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.activeChallenge case final c?) ...<Widget>[
                    const SizedBox(height: 12),
                    _ChallengeRow(challenge: c, clicks: widget.challengeClicks),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiRow extends StatelessWidget {
  const new(this.emojis);

  final List<String> emojis;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var i = 0; i < emojis.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 10),
        Text(emojis[i], style: const TextStyle(fontSize: 16)),
      ],
    ],
  );
}

/// The family challenge: a real progress ring, hidden when none runs — no
/// fake empty state.
class _ChallengeRow extends StatelessWidget {
  const new({required this.challenge, required this.clicks});

  final TasbihaChallenge challenge;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = challenge.targetClicks < 1 ? 1 : challenge.targetClicks;
    final progress = (clicks / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ZadPalette.kidsPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.square(
                  dimension: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    color: ZadPalette.kidsPrimary,
                    backgroundColor: ZadPalette.kidsPrimary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: ZadPalette.kidsPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  challenge.title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '$clicks من ${challenge.targetClicks} تسبيحة',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
