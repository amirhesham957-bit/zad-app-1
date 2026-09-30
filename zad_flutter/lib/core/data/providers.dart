/// The data layer's wiring.
///
/// Riverpod is the only state manager in this app and these are its
/// infrastructure singletons: nothing reaches for `Supabase.instance` or
/// `Hive.box` directly outside this file. Each feature's repository provider
/// lives beside its repository, in that feature's data folder; the outbox
/// reaches them through [OutboxWiring], which `app/wiring` binds.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/crash/crash_log.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/sync/app_sync_triggers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_runner.dart';
import 'package:zad/core/data/sync/outbox_wiring.dart';

/// The opened boxes.
///
/// Deliberately has no default. Boxes are opened in `bootstrap()` before the
/// first frame and injected here as an override; a default would let some
/// screen's first build open them instead, which is the same white-screen pause
/// the cache exists to remove.
final localStoreProvider = Provider<ZadLocalStore>(
  (ref) => throw StateError(
    'localStoreProvider was not overridden — see app/bootstrap.dart',
  ),
);

/// The Supabase client, initialised in `bootstrap()`.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// The on-phone crash log the support screen exports.
final crashLogProvider = Provider<CrashLog>(
  (ref) => CrashLog(ref.watch(localStoreProvider).device),
);

/// The signed-in user's id, read fresh on each call rather than captured, so a
/// sign-in or sign-out does not leave a stale id behind.
final signedInUserIdProvider = Provider<String? Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client.auth.currentUser?.id;
});

/// The clock.
///
/// Injected rather than read directly so a test, or a golden, is not at the
/// mercy of the time of day it happens to run at.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The queue of unsent writes.
///
/// The sender dispatches on the entry's kind, through [OutboxWiring] — the
/// kinds belong to the features, and `app/wiring/outbox_senders.dart` maps
/// each one to its repository. An unknown kind throws, which the outbox
/// classifies as transient and so retries before giving up — the right
/// behaviour if an update ever ships a box holding a kind this build does
/// not handle, because the alternative is discarding the user's write outright.
final Provider<Outbox> outboxProvider = Provider<Outbox>((ref) {
  final store = ref.watch(localStoreProvider);
  return Outbox(
    box: store.outbox,
    send: (entry) => OutboxWiring.send(ref, entry),
  );
});

/// Drains the outbox on startup, on resume, when the network comes back,
/// and on a slow tick that exists to wake entries out of their backoff.
///
/// Something has to hold this: a Provider nobody reads is never built, and an
/// outbox nobody flushes is just a list. `ZadApp` watches it for as long as
/// the app lives.
final Provider<OutboxRunner> outboxRunnerProvider = Provider<OutboxRunner>((
  ref,
) {
  final triggers = AppSyncTriggers(bankCaptures: OutboxWiring.captures(ref));
  final runner = OutboxRunner(
    outbox: ref.watch(outboxProvider),
    triggers: triggers.stream,
    // Ordering, not decoration: the inbox is emptied into the queue before the
    // queue is sent, so a notification captured while the app was closed goes
    // up on this cycle rather than the next one.
    beforeFlush: () => OutboxWiring.beforeFlush(ref),
  );

  ref.onDispose(() async {
    await runner.dispose();
    await triggers.dispose();
  });

  runner.start();
  return runner;
});
