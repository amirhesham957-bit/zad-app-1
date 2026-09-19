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
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

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

/// The signed-in user's id, read fresh on each call rather than captured, so a
/// sign-in or sign-out does not leave a stale id behind.
final signedInUserIdProvider = Provider<String? Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client.auth.currentUser?.id;
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
