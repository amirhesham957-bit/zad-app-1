/// The icon in a tinted rounded square: the sections grid's look, shared by
/// every Home tile so the glance, the reports and the sections read as one
/// family (emulator, 2026-11-10: three tile styles on one screen).
library;

import 'package:flutter/widgets.dart';

/// An icon on a soft square of its own colour.
class ZadIconChip extends StatelessWidget {
  /// Creates the chip.
  const new({
    required this.icon,
    required this.tint,
    this.size = 36,
    super.key,
  });

  /// The icon.
  final IconData icon;

  /// Its colour; the square is the same colour, faint.
  final Color tint;

  /// The square's side.
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.32),
      border: Border.all(color: tint.withValues(alpha: 0.2)),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: size * 0.55, color: tint),
  );
}
