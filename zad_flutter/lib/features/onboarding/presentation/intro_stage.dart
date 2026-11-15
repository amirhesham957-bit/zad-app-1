/// One page's stage: the painted scene, Zado standing in it, and his speech
/// bubble — all in the 430×420 design space, scaled to whatever height the
/// screen leaves (the owner's bug was a fixed-height card pushing the buttons
/// off a 360×640 phone).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/onboarding/presentation/intro_scenes.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Where Zado stands in each scene: left, top, size, mood.
const List<({double x, double y, double size, CompanionState mood})> _zado =
    <({double x, double y, double size, CompanionState mood})>[
      (x: 50, y: 175, size: 150, mood: CompanionState.happy),
      (x: 160, y: 250, size: 110, mood: CompanionState.happy),
      (x: 150, y: 145, size: 130, mood: CompanionState.celebrating),
      (x: 40, y: 200, size: 140, mood: CompanionState.happy),
    ];

/// The introduction's Zado is always the classic bare one, whatever the saved
/// choice — the screen is shown before any account or store is read.
class _BareAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

/// A page's scene with Zado and the bubble saying [say].
class IntroStage extends StatefulWidget {
  /// Creates the stage for [page] (0..3).
  const new({required this.page, required this.say, super.key});

  /// Which scene.
  final int page;

  /// What Zado says.
  final String say;

  @override
  State<IntroStage> createState() => _IntroStageState();
}

class _IntroStageState extends State<IntroStage> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: kIntroLoopDuration,
  );
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: kIntroGrowDuration,
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _bubbleTimer;
  bool _bubble = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _grow.value = 1;
      _pop.value = 1;
      _bubble = true;
      return;
    }
    _loop.repeat();
    _grow.forward();
    _bubbleTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _bubble = true);
      _pop.forward();
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _loop.dispose();
    _grow.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final z = _zado[widget.page];
    final spring = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeSemantics(
            child: FittedBox(
              child: SizedBox.fromSize(
                size: kIntroSceneSize,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: IntroScenePainter(
                            page: widget.page,
                            loop: _loop,
                            grow: _grow,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: z.x,
                      top: z.y,
                      width: z.size,
                      height: z.size,
                      child: ProviderScope(
                        overrides: [
                          orbAccessoryProvider.overrideWith(_BareAccessory.new),
                        ],
                        child: CompanionOrb(
                          state: z.mood,
                          size: z.size,
                          animated: !still,
                          look: const CompanionLook(),
                          occasion: OrbOccasion.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_bubble)
          PositionedDirectional(
            start: ZadSpacing.sm,
            top: ZadSpacing.sm,
            child: FadeTransition(
              opacity: _pop,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(spring),
                alignment: AlignmentDirectional.topStart.resolve(
                  Directionality.of(context),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x59064E3B),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: ZadSpacing.sm,
                    ),
                    child: Text(
                      widget.say,
                      style: ZadType.titleSmall.copyWith(
                        color: const Color(0xFF065F46),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
