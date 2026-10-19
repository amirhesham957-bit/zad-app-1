// The offline strip (ZAD_PLAN ٢.٤) says only what the queue's last flush
// said: the server was not answering and so many writes are waiting.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/app/shell/zad_pulse_bar.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';

OutboxFlushReport _report(FlushStop stop, int remaining) =>
    OutboxFlushReport(sent: 0, died: 0, remaining: remaining, stop: stop);

void main() {
  test('only an offline flush with something left says anything', () {
    expect(pulseText(null), isNull);
    expect(pulseText(_report(FlushStop.finished, 3)), isNull);
    expect(pulseText(_report(FlushStop.unauthenticated, 3)), isNull);
    expect(pulseText(_report(FlushStop.offline, 0)), isNull);
    expect(
      pulseText(_report(FlushStop.offline, 1)),
      'مفيش نت — حاجة واحدة محفوظة وهتتبعت أول ما النت يرجع',
    );
    expect(
      pulseText(_report(FlushStop.offline, 2)),
      contains('حاجتين محفوظين'),
    );
    expect(
      pulseText(_report(FlushStop.offline, 4)),
      contains('4 حاجات محفوظة'),
    );
    expect(
      pulseText(_report(FlushStop.offline, 14)),
      contains('14 حاجة محفوظة'),
    );
  });

  testWidgets('the strip comes with an offline report and goes with the next', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final last = container.read(outboxLastReportProvider.notifier);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ZadPulseBar()),
          ),
        ),
      ),
    );
    final strip = find.byKey(const ValueKey<String>('pulse-offline'));
    expect(strip, findsNothing);

    last.report = _report(FlushStop.offline, 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(strip, findsOneWidget);

    last.report = _report(FlushStop.finished, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(strip, findsNothing);

    // Watching the strip must not start the queue's runner (its 30 s tick
    // outlived every shell test once).
    expect(container.exists(outboxRunnerProvider), isFalse);

    // The pulse never settles; unmount before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a reply on its way outranks the queue; offline outranks sending', () {
    final offline = _report(FlushStop.offline, 2);
    expect(pulseLine(thinking: false, sending: false, report: null), isNull);
    expect(
      pulseLine(thinking: true, sending: true, report: offline)?.text,
      'زاد بيفكر…',
    );
    expect(
      pulseLine(thinking: false, sending: true, report: offline)?.key,
      'pulse-offline',
    );
    expect(
      pulseLine(thinking: false, sending: true, report: null)?.text,
      'بنزامن…',
    );
  });

  testWidgets('thinking and syncing come from their providers', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ZadPulseBar()),
          ),
        ),
      ),
    );
    final thinking = find.byKey(const ValueKey<String>('pulse-thinking'));
    final syncing = find.byKey(const ValueKey<String>('pulse-syncing'));

    container.read(outboxSendingProvider.notifier).sending = true;
    await tester.pump();
    expect(syncing, findsOneWidget);

    container.read(chatAwaitingReplyProvider.notifier).state = true;
    await tester.pump();
    expect(thinking, findsOneWidget);
    expect(syncing, findsNothing);

    container.read(chatAwaitingReplyProvider.notifier).state = false;
    container.read(outboxSendingProvider.notifier).sending = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(thinking, findsNothing);
    expect(syncing, findsNothing);
    expect(container.exists(chatControllerProvider), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
