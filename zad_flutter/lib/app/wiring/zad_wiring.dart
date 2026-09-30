/// Binds the shared contracts to the features that fulfil them.
///
/// Features never import each other: where one needs another — a queued
/// write sent by its repository, a screen opened from somewhere else — it
/// goes through a contract in core/ or shared/, and this is where the app
/// says which feature answers it. Called once in `bootstrap()` before the
/// first frame, and by `test/flutter_test_config.dart` before every test
/// file, so a test wires the same app the phone runs.
library;

import 'package:zad/app/wiring/account_scope_wiring.dart';
import 'package:zad/app/wiring/outbox_senders.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_wiring.dart';
import 'package:zad/shared/bank/data/bank_capture_marker.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';

/// Connects every contract. Safe to call more than once.
void wireZad() {
  wireAccountScope();
  OutboxWiring.bind(
    send: sendOutboxEntry,
    captures: (ref) => ref.read(bankListenerProvider).captures,
    beforeFlush: (ref) async {
      final report = await ref.read(notificationDrainProvider).drain();
      if (report.seen > 0) {
        await ref
            .read(bankCaptureMarkerProvider)
            .sawCapture(ref.read(nowProvider)());
      }
    },
  );
}
