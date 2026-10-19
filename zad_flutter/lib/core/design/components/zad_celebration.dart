/// One burst of confetti over the whole screen, with the haptic for something
/// completing (ZAD_PLAN ٢.٣). The caller decides that the moment is real and
/// fires it once for that moment; this only draws it.
///
/// Under reduced motion there is no confetti, only the haptic.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// How long the burst stays on screen before it is taken away, whether or not
/// the animation has finished (a missing asset must not leave a layer behind).
const Duration kZadCelebrationLength = Duration(milliseconds: 2400);

/// Bursts confetti over [context]'s overlay. Never throws, never waits.
void celebrate(BuildContext context) {
  // mediumImpact, not selectionClick: ZadPressable keeps the light click for
  // an acknowledgement; this is something finished.
  unawaited(HapticFeedback.mediumImpact());
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: Lottie.asset(
          'assets/lottie/lottie_confetti_burst.json',
          key: const ValueKey<String>('celebration'),
          repeat: false,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(kZadCelebrationLength, () {
    if (entry.mounted) entry.remove();
  });
}
