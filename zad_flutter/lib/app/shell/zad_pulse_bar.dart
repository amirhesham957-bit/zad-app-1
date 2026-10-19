/// The strip under the header that says what Zad is doing right now
/// (ZAD_PLAN ٢.٤): «زاد بيفكر…» while a chat turn waits for its reply,
/// «بنزامن…» while queued writes are being sent, and, from the queue's own
/// report, that the customer's writes are waiting for the network.
///
/// It never guesses. Each line comes from a real state: the chat's
/// `isAwaitingReply`, the runner's sending signal, and the last flush's report
/// (the server was not answering and so many entries are still queued).
/// Before it, a customer offline saw nothing at all, and an expense that «did
/// not arrive» on another phone looked lost. The offline line goes as soon as
/// a flush ends any other way.
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
import 'package:zad/shared/chat/application/chat_controller.dart';

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

/// Which line the strip shows, or null for none.
///
/// A reply on its way outranks the queue: it is what the customer is
/// waiting for. Offline outranks sending, because a send while offline is a
/// retry that is about to fail again and the offline line would blink.
({String key, String text})? pulseLine({
  required bool thinking,
  required bool sending,
  required OutboxFlushReport? report,
}) {
  if (thinking) return (key: 'pulse-thinking', text: 'زاد بيفكر…');
  if (pulseText(report) case final offline?) {
    return (key: 'pulse-offline', text: offline);
  }
  if (sending) return (key: 'pulse-syncing', text: 'بنزامن…');
  return null;
}

/// The strip, or nothing.
class ZadPulseBar extends ConsumerWidget {
  /// Creates the strip.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = pulseLine(
      thinking: ref.watch(chatAwaitingReplyProvider),
      sending: ref.watch(outboxSendingProvider),
      report: ref.watch(outboxLastReportProvider),
    );
    final tone = line?.key == 'pulse-thinking'
        ? ZadColors.green700
        : ZadColors.slate;
    return AnimatedSize(
      duration: ZadDuration.press,
      curve: ZadCurves.press,
      child: line == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                key: ValueKey<String>(line.key),
                width: double.infinity,
                color: tone.withValues(alpha: 0.08),
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
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Expanded(
                      child: Text(
                        line.text,
                        style: ZadType.labelMedium.copyWith(color: tone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
