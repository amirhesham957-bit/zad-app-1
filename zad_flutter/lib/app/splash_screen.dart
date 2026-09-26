/// Kotlin's `SplashScreen` (MainActivity.kt): a warm off-white canvas with two
/// blurred ambient blobs, the carrot mark bouncing in and then floating
/// (`ZadAnimatedLogo`), «زاد», the slogan and the privacy line — two seconds,
/// and only on a start that is not already signed in, as Kotlin skips it for
/// a returning, set-up account.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zad/app/auth_gate.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/features/auth/application/session_controller.dart';

const Color _canvas = Color(0xFFFBFAF8);
const Color _textTertiary = Color(0xFF6E7065);

/// The app's root: the splash on a cold, signed-out start, then the gate.
class ZadSplashGate extends ConsumerStatefulWidget {
  /// Creates the root.
  const new({super.key});

  @override
  ConsumerState<ZadSplashGate> createState() => _ZadSplashGateState();
}

class _ZadSplashGateState extends ConsumerState<ZadSplashGate> {
  late bool _splash = ref.read(sessionControllerProvider) == null;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_splash) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _splash = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    child: _splash ? const SplashScreen() : const ZadAuthGate(),
  );
}

/// The splash itself.
class SplashScreen extends StatefulWidget {
  /// Creates the splash.
  const new({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Kotlin: the column fades in over `tween(1000)` — whose default easing is
  // FastOutSlowIn — and the logo enters in 700ms (FastOutSlowIn) then floats
  // 6dp up and back every 1500ms (linear).
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();
  late final Animation<double> _fadeCurve = CurvedAnimation(
    parent: _fade,
    curve: Curves.fastOutSlowIn,
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _fade.dispose();
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        const PositionedDirectional(
          top: -60,
          start: -80,
          child: _Blob(Color(0xFFFCD3C7)),
        ),
        const PositionedDirectional(
          bottom: -60,
          end: -80,
          child: _Blob(Color(0xFFBFE3D1)),
        ),
        FadeTransition(
          opacity: _fadeCurve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_enter, _float]),
                builder: (context, child) {
                  final e = Curves.fastOutSlowIn.transform(_enter.value);
                  final scale = e < 0.6
                      ? 0.7 + (e / 0.6) * 0.36
                      : 1.06 - ((e - 0.6) / 0.4) * 0.06;
                  final degrees = e < 0.6
                      ? -8 + (e / 0.6) * 10
                      : 2 - ((e - 0.6) / 0.4) * 2;
                  return Opacity(
                    opacity: e.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, -6 * _float.value * e.clamp(0, 1)),
                      child: Transform.rotate(
                        angle: degrees * math.pi / 180,
                        child: Transform.scale(scale: scale, child: child),
                      ),
                    ),
                  );
                },
                child: SvgPicture.asset(
                  'assets/brand/carrot_logo.svg',
                  width: 80,
                  height: 80,
                  semanticsLabel: 'ZAD Logo',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'زاد',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: ZadColors.forestLight,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تدبير ذكي لبيت هادئ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ZadColors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'خصوصية بياناتك أولوية، دائماً',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: _textTertiary,
                ),
              ),
              const SizedBox(height: 60),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ZadColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Kotlin's blob, layer for layer: `clip(CircleShape)` outside,
/// `zadGlassBlur(80.dp)` inside it, then the 55% fill. Compose's `blur` with
/// its default `BlurredEdgeTreatment.Rectangle` clips to its own bounds and
/// clamps the edge, so the same filter here is `TileMode.clamp` inside a
/// `ClipRect`, and the circle clip wraps both. Android converts a blur radius
/// to sigma as `0.57735 * r + 0.5`.
class _Blob extends StatelessWidget {
  const new(this.color);

  final Color color;

  static const double _sigma = 0.57735 * 80 + 0.5;

  @override
  // Its own layer: the logo floats forever above it, and a blur this wide
  // is the one thing on the splash that must not be redrawn every frame.
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipOval(
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _sigma,
            sigmaY: _sigma,
            tileMode: TileMode.clamp,
          ),
          child: SizedBox.square(
            dimension: 320,
            child: ColoredBox(color: color.withValues(alpha: 0.55)),
          ),
        ),
      ),
    ),
  );
}
