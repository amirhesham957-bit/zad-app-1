/// Kotlin's `DraggableFloatingCompanion`: the 62dp orb floating 36dp above
/// the bar and 18dp in from the start edge, on الرئيسية only.
///
/// * a tap — chirp, a short buzz, two blinks and the halo, a 1.22 bounce, and
///   a speech bubble for 3.5s (tapping the bubble opens the voice);
/// * a double tap — the celebration trill, and the chat opens;
/// * a long press — the chirp and a stronger buzz, and the voice opens;
/// * a drag — a purr, the orb grows to 1.14 and looks happy, then springs
///   home on release (Compose's MediumBouncy / StiffnessLow).
///
/// It fades out while the keyboard is up, so it never sits over a field.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/orb/application/companion_mood.dart';
import 'package:zad/features/orb/application/pet_sound.dart';
import 'package:zad/features/orb/domain/companion_state.dart';
import 'package:zad/features/orb/presentation/companion_orb.dart';

/// The floating orb. Put it in a [Stack] over the screen's body.
class FloatingCompanion extends ConsumerStatefulWidget {
  /// Creates it.
  const new({required this.onOpenVoice, required this.onOpenChat, super.key});

  /// Long press, and the bubble.
  final VoidCallback onOpenVoice;

  /// Double tap.
  final VoidCallback onOpenChat;

  @override
  ConsumerState<FloatingCompanion> createState() => _FloatingCompanionState();
}

class _FloatingCompanionState extends ConsumerState<FloatingCompanion>
    with TickerProviderStateMixin {
  // Compose's MediumBouncy (0.5) at StiffnessLow (200), mass 1.
  static const SpringDescription _home = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 2 * 0.5 * 14.142135623731,
  );
  // ZadSprings.Celebrate (0.4 / 500) out, ZadSprings.Press (0.55 / 600) back.
  static const SpringDescription _celebrate = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 2 * 0.4 * 22.360679774998,
  );
  static const SpringDescription _press = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 2 * 0.55 * 24.494897427832,
  );

  late final AnimationController _dx = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _dy = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _tap = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool _dragging = false;
  bool _bubble = false;
  int _blink = 0;
  int _glow = 0;
  Timer? _bubbleTimer;
  DateTime? _lastTap;

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _dx.dispose();
    _dy.dispose();
    _tap.dispose();
    super.dispose();
  }

  // Kotlin buzzes a one-shot of a given length and amplitude; Flutter's
  // haptics are graded, so the strength steps stand in for the amplitudes.
  void _buzz(int amplitude) => unawaited(
    amplitude >= 220
        ? HapticFeedback.heavyImpact()
        : amplitude >= 140
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact(),
  );

  Future<void> _bounce() async {
    await _tap.animateWith(SpringSimulation(_celebrate, _tap.value, 1.22, 0));
    if (!mounted) return;
    await _tap.animateWith(SpringSimulation(_press, _tap.value, 1, 0));
  }

  void _onTap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 300)) {
      // Double tap: the chat.
      _lastTap = null;
      setState(() => _bubble = false);
      _buzz(220);
      playPetSound(PetSound.celebrationTrill, volume: 0.5);
      widget.onOpenChat();
      return;
    }
    _lastTap = now;
    _buzz(200);
    playPetSound(PetSound.happyChirp, volume: 0.5);
    final t = now.millisecondsSinceEpoch;
    setState(() {
      _blink = t;
      _glow = t;
      _bubble = true;
    });
    unawaited(_bounce());
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _bubble = false);
    });
  }

  void _onLongPress() {
    if (_dragging) return;
    setState(() => _bubble = false);
    _buzz(240);
    playPetSound(PetSound.happyChirp, volume: 0.5);
    widget.onOpenVoice();
  }

  void _onDragStart(DragStartDetails _) {
    setState(() {
      _dragging = true;
      _bubble = false;
    });
    _buzz(140);
    playPetSound(PetSound.purr, volume: 0.4);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _dx.value += d.delta.dx;
    _dy.value += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails _) {
    setState(() => _dragging = false);
    _buzz(100);
    _dx.animateWith(SpringSimulation(_home, _dx.value, 0, 0));
    _dy.animateWith(SpringSimulation(_home, _dy.value, 0, 0));
  }

  String _bubbleText(CompanionState mood) => switch (mood) {
    CompanionState.happy => 'يومك سعيد وكل شيء منظم 🌿',
    CompanionState.alert => 'انتبه لميزانيتك ومواعيدك 👀',
    CompanionState.celebrating => 'إنجاز رائع! استمر كده 🎉',
    _ => 'جاهز لمساعدتك في أي وقت 👋',
  };

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final mood = _dragging
        ? CompanionState.happy
        : ref.watch(companionMoodProvider);
    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      ignoring: keyboard,
      child: AnimatedOpacity(
        opacity: keyboard ? 0 : 1,
        duration: Duration(milliseconds: keyboard ? 160 : 220),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            // Kotlin pads `bottomNavHeight (80) + 36` = 116dp up from the
            // system bar. This body already ends at the top of the bar's
            // 96dp box (74 + 22), so 20 more lands it on the same line.
            // 18dp in from the start edge.
            padding: const EdgeInsetsDirectional.only(start: 18, bottom: 20),
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_dx, _dy]),
              builder: (_, child) => Transform.translate(
                offset: Offset(_dx.value, _dy.value),
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedOpacity(
                      opacity: _bubble ? 1 : 0,
                      duration: Duration(milliseconds: _bubble ? 180 : 140),
                      child: _bubble
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _Bubble(
                                text: _bubbleText(mood),
                                surface: scheme.surface,
                                outline: scheme.outlineVariant,
                                ink: scheme.onSurface,
                                onTap: () {
                                  setState(() => _bubble = false);
                                  widget.onOpenVoice();
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTap,
                    onLongPress: _onLongPress,
                    onPanStart: _onDragStart,
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: AnimatedBuilder(
                      animation: _tap,
                      builder: (_, child) => Transform.scale(
                        scale: _tap.value * (_dragging ? 1.14 : 1),
                        child: child,
                      ),
                      child: CompanionOrb(
                        state: mood,
                        size: 62,
                        blinkTrigger: _blink,
                        glowTrigger: _glow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The speech bubble: 16dp corners, surface at 95%, a hairline, elevation 6,
/// at most 210dp wide.
class _Bubble extends StatelessWidget {
  const new({
    required this.text,
    required this.surface,
    required this.outline,
    required this.ink,
    required this.onTap,
  });

  final String text;
  final Color surface;
  final Color outline;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 210),
    child: Material(
      color: surface.withValues(alpha: 0.95),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 15 / 11,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    ),
  );
}
