/// The data layer's wiring.
///
/// Riverpod is the only state manager in this app and these are the only
/// singletons: nothing reaches for `Supabase.instance` or `Hive.box` directly
/// outside this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/sync/app_sync_triggers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/data/sync/outbox_runner.dart';
import 'package:zad/features/auth/data/auth_gateway.dart';
import 'package:zad/features/bank/data/bank_capture_marker.dart';
import 'package:zad/features/bank/data/bank_remote.dart';
import 'package:zad/features/bank/data/notification_drain.dart';
import 'package:zad/features/bank/domain/tracked_financial_apps.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/proposals/data/proposals_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

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

/// Signing in, signing up, signing out.
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's id, read fresh on each call rather than captured, so a
/// sign-in or sign-out does not leave a stale id behind.
final signedInUserIdProvider = Provider<String? Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client.auth.currentUser?.id;
});

/// The Android capture inbox.
final bankListenerProvider = Provider<ZadBankListener>(
  (ref) => const ZadBankListener(),
);

/// Remembers whether this device has ever captured anything.
final bankCaptureMarkerProvider = Provider<BankCaptureMarker>(
  (ref) => BankCaptureMarker(ref.watch(localStoreProvider).documents),
);

/// Empties the capture inbox into the outbox.
///
/// Read lazily by the runner, so this provider does not need the outbox at
/// construction time.
final Provider<NotificationDrain> notificationDrainProvider =
    Provider<NotificationDrain>((ref) {
      return NotificationDrain(
        listener: ref.watch(bankListenerProvider),
        outbox: ref.read(outboxProvider),
        newId: const Uuid().v4,
        signedInUserId: ref.watch(signedInUserIdProvider),
        isTrackedFinancialApp: isTrackedFinancialApp,
      );
    });

/// Hands bank notifications to zad-brain.
final bankRemoteProvider = Provider<BankRemote>(
  (ref) => SupabaseBankRemote(ref.watch(supabaseClientProvider)),
);

/// The clock.
///
/// Injected rather than read directly so a test, or a golden, is not at the
/// mercy of the time of day it happens to run at.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The budget, read from `zad_budget_state()` and cached.
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  return BudgetRepository(
    cache: store.documents,
    remote: SupabaseBudgetRemote(ref.watch(supabaseClientProvider)),
    signedInUserId: ref.watch(signedInUserIdProvider),
  );
});

/// Bank transactions waiting for the customer to say yes.
final proposalsRepositoryProvider = Provider<ProposalsRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  return ProposalsRepository(
    cache: store.documents,
    remote: SupabaseProposalsRemote(ref.watch(supabaseClientProvider)),
    signedInUserId: ref.watch(signedInUserIdProvider),
  );
});

/// The server side of transactions.
final transactionsRemoteProvider = Provider<TransactionsRemote>(
  (ref) => SupabaseTransactionsRemote(ref.watch(supabaseClientProvider)),
);

/// The queue of unsent writes.
///
/// The sender dispatches on the entry's kind. An unknown kind throws, which the
/// outbox classifies as transient and so retries before giving up — the right
/// behaviour if an update ever ships a box holding a kind this build does
/// not handle, because the alternative is discarding the user's write outright.
// Explicitly typed, both of them: these two providers refer to each other, and
// without a written-out type Dart cannot infer either one through the cycle.
final Provider<Outbox> outboxProvider = Provider<Outbox>((ref) {
  final store = ref.watch(localStoreProvider);
  return Outbox(
    box: store.outbox,
    send: (entry) async => switch (entry.kind) {
      OutboxKind.insertTransaction =>
        await ref.read(transactionsRepositoryProvider).sendQueued(entry),
      OutboxKind.notificationIngest =>
        await ref.read(bankRemoteProvider).ingestNotification(entry.payload),
      _ => throw StateError('no sender for outbox kind "${entry.kind}"'),
    },
  );
});

/// Transactions, offline first.
final Provider<TransactionsRepository>
transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  return TransactionsRepository(
    cache: store.transactions,
    remote: ref.watch(transactionsRemoteProvider),
    // Read lazily: the outbox sends through this repository, so resolving it
    // here would be a cycle.
    outbox: () => ref.read(outboxProvider),
    newId: const Uuid().v4,
    signedInUserId: ref.watch(signedInUserIdProvider),
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
  final triggers = AppSyncTriggers();
  final runner = OutboxRunner(
    outbox: ref.watch(outboxProvider),
    triggers: triggers.stream,
    // Ordering, not decoration: the inbox is emptied into the queue before the
    // queue is sent, so a notification captured while the app was closed goes
    // up on this cycle rather than the next one.
    beforeFlush: () async {
      final report = await ref.read(notificationDrainProvider).drain();
      if (report.seen > 0) {
        await ref
            .read(bankCaptureMarkerProvider)
            .sawCapture(ref.read(nowProvider)());
      }
    },
  );

  ref.onDispose(() async {
    await runner.dispose();
    await triggers.dispose();
  });

  runner.start();
  return runner;
});
