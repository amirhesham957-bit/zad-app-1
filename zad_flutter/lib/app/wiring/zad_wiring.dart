/// Binds the shared contracts to the features that fulfil them.
///
/// Features never import each other: where one needs another — a queued
/// write sent by its repository, a screen opened from somewhere else — it
/// goes through a contract in core/ or shared/, and this is where the app
/// says which feature answers it. Called once in `bootstrap()` before the
/// first frame, and by `test/flutter_test_config.dart` before every test
/// file, so a test wires the same app the phone runs.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/app/wiring/account_scope_wiring.dart';
import 'package:zad/app/wiring/outbox_senders.dart';
import 'package:zad/app/wiring/screens_wiring.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox_wiring.dart';
import 'package:zad/shared/bank/data/bank_capture_marker.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/session/product_events.dart';

/// Connects every contract. Safe to call more than once.
void wireZad() {
  wireAccountScope();
  wireScreens();
  wireSlots();
  OutboxWiring.bind(
    send: sendOutboxEntry,
    captures: (ref) => ref.read(bankListenerProvider).captures,
    beforeFlush: (ref) async {
      final DrainReport report;
      try {
        report = await ref.read(notificationDrainProvider).drain();
      } on Object catch (e) {
        // The runner keeps going without the inbox and only remembers the
        // error in memory — so a drain that fails on every flush is a bank
        // channel that never sends and never says so (the owner, 2026-11-04).
        _event(ref, bankDrainFailedEvent(e));
        rethrow;
      }
      if (report.seen > 0) {
        await ref
            .read(bankCaptureMarkerProvider)
            .sawCapture(ref.read(nowProvider)());
      }
      if (report.queued > 0) _event(ref, 'bank.queued');
    },
  );
}

/// A statistic, never a failure of its own.
void _event(Ref ref, String name) {
  try {
    unawaited(
      ref
          .read(productEventsProvider)
          .log(name, every: const Duration(hours: 6))
          .catchError((Object _) => false),
    );
  } on Object {
    // No session graph (a test host).
  }
}

/// The event for a drain that threw: its type, lower-cased to the event name
/// rule (`bank.drain_failed.platformexception`), never its message.
String bankDrainFailedEvent(Object error) {
  final type = error.runtimeType.toString().toLowerCase().replaceAll(
    RegExp('[^a-z0-9_]'),
    '',
  );
  final kind = type.isEmpty ? 'unknown' : type;
  return 'bank.drain_failed.${kind.length > 24 ? kind.substring(0, 24) : kind}';
}
