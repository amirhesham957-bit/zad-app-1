/// The guided tour: a light that moves over the app's real buttons and says
/// what each one is for (owner, 2026-11-09: the customer gets lost).
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';

/// The controls the tour points at, placed where each one is drawn.
abstract final class ZadTourKeys {
  /// الرئيسية.
  static final GlobalKey home = GlobalKey(debugLabel: 'tour-home');

  /// فلوسي.
  static final GlobalKey money = GlobalKey(debugLabel: 'tour-money');

  /// بيتي.
  static final GlobalKey house = GlobalKey(debugLabel: 'tour-house');

  /// المزيد.
  static final GlobalKey more = GlobalKey(debugLabel: 'tour-more');

  /// The mic orb.
  static final GlobalKey mic = GlobalKey(debugLabel: 'tour-mic');

  /// The camera button.
  static final GlobalKey camera = GlobalKey(debugLabel: 'tour-camera');

  /// The bell.
  static final GlobalKey bell = GlobalKey(debugLabel: 'tour-bell');
}

/// One stop: what it is called, what it does, and what to light.
class ZadTourStep {
  /// Creates a stop; a null [target] is said in the middle of the screen.
  const new({required this.title, required this.body, this.target});

  /// The name.
  final String title;

  /// What it does.
  final String body;

  /// The control to light.
  final GlobalKey? target;
}

/// Opens the tour over the shell, skipping anything not on screen.
Future<void> showZadTour(BuildContext context) {
  final l = context.l10n;
  final steps = <ZadTourStep>[
    ZadTourStep(title: l.tourWelcomeTitle, body: l.tourWelcomeBody),
    ZadTourStep(
      title: l.tourHomeTitle,
      body: l.tourHomeBody,
      target: ZadTourKeys.home,
    ),
    ZadTourStep(
      title: l.tourMoneyTitle,
      body: l.tourMoneyBody,
      target: ZadTourKeys.money,
    ),
    ZadTourStep(
      title: l.tourMicTitle,
      body: l.tourMicBody,
      target: ZadTourKeys.mic,
    ),
    ZadTourStep(
      title: l.tourCameraTitle,
      body: l.tourCameraBody,
      target: ZadTourKeys.camera,
    ),
    ZadTourStep(
      title: l.tourHouseTitle,
      body: l.tourHouseBody,
      target: ZadTourKeys.house,
    ),
    ZadTourStep(
      title: l.tourMoreTitle,
      body: l.tourMoreBody,
      target: ZadTourKeys.more,
    ),
    ZadTourStep(
      title: l.tourBellTitle,
      body: l.tourBellBody,
      target: ZadTourKeys.bell,
    ),
  ].where((s) => s.target == null || s.target!.currentContext != null).toList();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: ZadDuration.enter,
      reverseTransitionDuration: ZadDuration.quick,
      pageBuilder: (_, _, _) => ZadTourOverlay(steps: steps),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The overlay.
class ZadTourOverlay extends StatefulWidget {
  /// Creates the overlay for [steps].
  const new({required this.steps, super.key});

  /// The stops, in order.
  final List<ZadTourStep> steps;

  @override
  State<ZadTourOverlay> createState() => _ZadTourOverlayState();
}

class _ZadTourOverlayState extends State<ZadTourOverlay> {
  int _step = 0;

  Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    // The transform, not the size alone: the bar's tabs sit in a FittedBox.
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    ).inflate(ZadSpacing.sm);
  }

  void _next() {
    if (_step + 1 >= widget.steps.length) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final step = widget.steps[_step];
    final last = _step == widget.steps.length - 1;
    final hole = _rectOf(step.target);
    final middle = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 0,
      height: 0,
    );
    final card = _TourCard(
      key: ValueKey<int>(_step),
      step: step,
      count: l.tourStepOf('${_step + 1}', '${widget.steps.length}'),
      nextLabel: last ? l.tourDone : l.tourNext,
      skipLabel: last ? null : l.tourSkip,
      onNext: _next,
      onSkip: () => Navigator.of(context).pop(),
    );
    final switched = AnimatedSwitcher(
      duration: still ? Duration.zero : ZadDuration.quick,
      child: card,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            // The app under the light is not tapped during the tour.
            child: AbsorbPointer(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole ?? middle),
                duration: still ? Duration.zero : ZadDuration.settle,
                curve: ZadCurves.standard,
                builder: (_, rect, _) =>
                    CustomPaint(painter: _ScrimPainter(rect ?? middle)),
              ),
            ),
          ),
          if (hole == null)
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ZadSpacing.xl),
                    child: switched,
                  ),
                ),
              ),
            )
          else if (hole.center.dy > size.height / 2)
            Positioned(
              left: ZadSpacing.xl,
              right: ZadSpacing.xl,
              bottom: size.height - hole.top + ZadSpacing.xl,
              child: switched,
            )
          else
            Positioned(
              left: ZadSpacing.xl,
              right: ZadSpacing.xl,
              top: hole.bottom + ZadSpacing.xl,
              child: switched,
            ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const new({
    required this.step,
    required this.count,
    required this.nextLabel,
    required this.skipLabel,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final ZadTourStep step;
  final String count;
  final String nextLabel;
  final String? skipLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ZadSpacing.xl),
    decoration: BoxDecoration(
      gradient: ZadColors.hero,
      borderRadius: BorderRadius.circular(ZadRadii.hero),
      border: Border.all(color: ZadColors.glassEdge),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          count,
          style: ZadType.labelSmall.copyWith(color: ZadColors.mintGlow),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          step.title,
          style: ZadType.headlineMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: ZadSpacing.sm),
        Text(
          step.body,
          style: ZadType.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: ZadSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: Colors.white,
                  foregroundColor: ZadColors.green800,
                ),
                child: Text(nextLabel),
              ),
            ),
            if (skipLabel case final skip?) ...<Widget>[
              const SizedBox(width: ZadSpacing.sm),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  foregroundColor: Colors.white,
                ),
                child: Text(skip),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ScrimPainter extends CustomPainter {
  const new(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final light = RRect.fromRectAndRadius(
      hole,
      const Radius.circular(ZadRadii.cardLarge),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(light),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    if (hole.isEmpty) return;
    canvas.drawRRect(
      light,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ZadColors.mintGlow,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
