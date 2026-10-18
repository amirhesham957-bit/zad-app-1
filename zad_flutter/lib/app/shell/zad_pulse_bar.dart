/// The strip under the header that says, from the queue's own report, that
/// the customer's writes are waiting for the network (ZAD_PLAN ٢.٤).
///
/// It never guesses. It shows only what the last flush said: the server was
/// not answering and so many entries are still queued. Before it, a customer
/// offline saw nothing at all, and an expense that «did not arrive» on
/// another phone looked lost. It goes as soon as a flush ends any other way.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';

/// What the strip says for [report], or null when there is nothing waiting.
String? pulseText(OutboxFlushReport? report) {
  if (report == null || report.stop != FlushStop.offline) return null;
  final n = report.remaining;
  if (n <= 0) return null;
  final what = switch (n) {
    1 => 'حاجة واحدة محفوظة',
    2 => 'حاجتين محفوظين',
    <= 10 => '$n حاجات محفوظة',
    _ => '$n حاجة محفوظة',
  };
  return 'مفيش نت — $what وهتتبعت أول ما النت يرجع';
}

/// The strip, or nothing.
class ZadPulseBar extends ConsumerWidget {
  /// Creates the strip.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = pulseText(ref.watch(outboxLastReportProvider));
    return AnimatedSize(
      duration: ZadDuration.press,
      curve: ZadCurves.press,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey<String>('pulse-offline'),
                width: double.infinity,
                color: ZadColors.slate.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.lg,
                  vertical: ZadSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    ZadDotPulse(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ZadColors.slate,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: ZadType.labelMedium.copyWith(
                          color: ZadColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
