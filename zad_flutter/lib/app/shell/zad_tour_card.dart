/// The two pieces the guided tour draws: its card and the dim layer.
library;

import 'package:flutter/material.dart';
import 'package:zad/app/shell/zad_tour.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// The card that says what the lit control does.
class TourCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.step,
    required this.count,
    required this.nextLabel,
    required this.skipLabel,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  /// The stop.
  final ZadTourStep step;

  /// «3 من 8».
  final String count;

  /// The main button.
  final String nextLabel;

  /// The way out, or null on the last stop.
  final String? skipLabel;

  /// Goes on.
  final VoidCallback onNext;

  /// Closes the tour.
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

/// The dim layer with the light cut out of it.
class TourScrimPainter extends CustomPainter {
  /// Creates the painter for the light at [hole].
  const new(this.hole);

  /// Where the light is.
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
  bool shouldRepaint(TourScrimPainter old) => old.hole != hole;
}
