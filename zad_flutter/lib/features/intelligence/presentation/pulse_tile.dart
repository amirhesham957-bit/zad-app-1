/// One small figure under the pulse line in `brain_pulse.dart`.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// One small figure under the pulse line.
class PulseTile extends StatelessWidget {
  /// Creates the tile.
  const new({
    required this.label,
    required this.value,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  /// What it measures.
  final String label;

  /// The figure.
  final String value;

  /// A tap, or null when there is nothing to do.
  final VoidCallback? onTap;

  /// Lit while its day is picked.
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: ZadDuration.quick,
    curve: ZadCurves.standard,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: selected ? 0.26 : 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZadRadii.chip),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
