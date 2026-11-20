/// A drawing that flies from one widget to another — the bought item going
/// to the pantry counter. It is feedback ("it went there"), so a phone set
/// to reduce motion gets none.
library;

import 'package:flutter/material.dart';

/// Flies [art] from the middle of [from] to the widget [to] marks, in
/// 600 ms. Does nothing when animations are
/// off or either end is not on screen.
void flyArt(BuildContext from, GlobalKey to, Widget art, {double size = 32}) {
  if (MediaQuery.maybeDisableAnimationsOf(from) ?? false) return;
  final overlay = Overlay.maybeOf(from);
  final start = from.findRenderObject();
  final end = to.currentContext?.findRenderObject();
  if (overlay == null ||
      start is! RenderBox ||
      end is! RenderBox ||
      !start.attached ||
      !end.attached) {
    return;
  }
  final a = start.localToGlobal(start.size.center(Offset.zero));
  final b = end.localToGlobal(end.size.center(Offset.zero));
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flight(
      key: const ValueKey<String>('art-flight'),
      from: a,
      to: b,
      size: size,
      art: art,
      onDone: () {
        entry
          ..remove()
          ..dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _Flight extends StatelessWidget {
  const new({
    required this.from,
    required this.to,
    required this.size,
    required this.art,
    required this.onDone,
    super.key,
  });

  final Offset from;
  final Offset to;
  final double size;
  final Widget art;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Stack(
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            onEnd: onDone,
            builder: (_, t, child) {
              // A small arc: up first, then down onto the counter.
              final lift = -48 * (1 - (2 * t - 1) * (2 * t - 1));
              final p = Offset.lerp(from, to, t)! + Offset(0, lift);
              return Positioned(
                left: p.dx - size / 2,
                top: p.dy - size / 2,
                child: Opacity(
                  opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
                  child: Transform.scale(scale: 1 - 0.5 * t, child: child),
                ),
              );
            },
            child: SizedBox.square(dimension: size, child: art),
          ),
        ],
      ),
    ),
  );
}
