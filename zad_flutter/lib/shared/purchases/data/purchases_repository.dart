/// The purchase door on the phone: a receipt's money and lines go to
/// `zad_record_purchase` as one queued write (ZAD_PLAN ٣.٦ ب).
///
/// Before this the receipt sheet and the camera wrote the expense, the
/// pantry, the prices and the pharmacy as separate calls in different orders,
/// and any failure in between left half a purchase behind. Now one outbox
/// entry carries all of it and the server writes it in one transaction.
///
/// The expense shows at once (pending), as any other write does. The pantry
/// and the pharmacy are read back from the server once the purchase is
/// answered: their rows are the server's to name and match, and a copy
/// planned here would disagree with them.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/shared/purchases/data/purchases_remote.dart';
import 'package:zad/shared/purchases/domain/purchase.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Records purchases.
class PurchasesRepository {
  /// Creates a repository.
  ///
  /// [flush] sends the queue now; [afterRecorded] reads back what the
  /// purchase changed. [wait] bounds how long [record] waits for an answer
  /// before telling the caller the purchase is queued.
  new({
    required PurchasesRemote remote,
    required Outbox Function() outbox,
    required TransactionsRepository transactions,
    required Future<void> Function() flush,
    required Future<void> Function(PurchaseOutcome outcome) afterRecorded,
    required String Function() newId,
    Duration wait = const Duration(seconds: 20),
  }) : _remote = remote,
       _outbox = outbox,
       _transactions = transactions,
       _flush = flush,
       _afterRecorded = afterRecorded,
       _newId = newId,
       _wait = wait;

  final PurchasesRemote _remote;
  final Outbox Function() _outbox;
  final TransactionsRepository _transactions;
  final Future<void> Function() _flush;
  final Future<void> Function(PurchaseOutcome outcome) _afterRecorded;
  final String Function() _newId;
  final Duration _wait;

  /// Answers that arrived, by purchase id, until [record] collects them.
  final Map<String, PurchaseOutcome> _answered = <String, PurchaseOutcome>{};

  /// A fresh purchase id — a uuid, which the function requires.
  String newId() => _newId();

  /// The outbox id for purchase [id].
  static String outboxIdFor(String id) => 'purchase:$id';

  /// Queues [purchase] and tries to send it now.
  ///
  /// [shownAs] is the expense as the phone should show it until the server
  /// answers: the new row, or the bank's row with the shop on it. Returns
  /// what the server did, or null when it has not answered yet — no network,
  /// or older writes still ahead of it in the queue — and the purchase goes
  /// when they do.
  Future<PurchaseOutcome?> record(
    Purchase purchase, {
    required ZadTransaction shownAs,
  }) async {
    await _transactions.holdUnsent(shownAs);
    await _outbox().enqueue(
      id: outboxIdFor(purchase.id),
      kind: OutboxKind.recordPurchase,
      payload: purchase.toJson(),
    );
    try {
      await _flush().timeout(_wait);
    } on Object {
      // Still queued; the next flush sends it.
    }
    return _answered.remove(purchase.id);
  }

  /// Sends one queued purchase. Registered as the outbox's sender for
  /// [OutboxKind.recordPurchase].
  Future<void> sendQueued(OutboxEntry entry) async {
    var payload = entry.payload;
    var answer = await _remote.record(payload);

    // A same-amount expense minutes away that the phone did not have when it
    // asked «دي نفس العملية؟» — the bank's row, most often, which arrived in
    // the meantime. Nothing was written, and nobody is waiting here to be
    // asked, so it is taken as the sheet's own default answer: one payment,
    // one expense, with the lines still going in.
    if (answer['status'] == 'duplicate_suspected') {
      final twin = switch (answer['twin']) {
        final Map<dynamic, dynamic> m => m['id']?.toString(),
        _ => null,
      };
      if (twin == null) {
        throw const ServerRefusal('zad_record_purchase', 'duplicate_suspected');
      }
      payload = <String, dynamic>{...payload, 'merge_with': twin};
      answer = await _remote.record(payload);
    }

    // The bank's row was deleted after the phone chose it: the purchase is
    // its own expense rather than nothing at all.
    if (answer['reason'] == 'merge_target_not_found') {
      payload = <String, dynamic>{...payload, 'allow_duplicate': true}
        ..remove('merge_with');
      answer = await _remote.record(payload);
    }

    // Refused for good (`invalid_input`, `id_in_use`): a dead letter, so the
    // customer can see what did not save.
    final outcome =
        PurchaseOutcome.fromJson(answer) ??
        (throw ServerRefusal(
          'zad_record_purchase',
          answer['reason']?.toString() ?? '$answer',
        ));

    final id = payload['id'] as String;
    if (outcome.transactionId != id) await _transactions.forget(id);
    final row = await _remote.fetchTransaction(outcome.transactionId);
    if (row != null) await _transactions.confirm(row);

    try {
      await _afterRecorded(outcome);
    } on Object {
      // The purchase is written; the pantry's copy catches up on its next
      // refresh.
    }
    _answered[id] = outcome;
  }
}

/// The purchase door.
final Provider<PurchasesRepository> purchasesRepositoryProvider =
    Provider<PurchasesRepository>(
      (ref) => PurchasesRepository(
        remote: SupabasePurchasesRemote(ref.watch(supabaseClientProvider)),
        // Read lazily: the outbox sends through this repository.
        outbox: () => ref.read(outboxProvider),
        transactions: ref.watch(transactionsRepositoryProvider),
        flush: () => ref.read(outboxRunnerProvider).flushNow(),
        newId: const Uuid().v4,
        afterRecorded: (outcome) async {
          final touchedPantry =
              outcome.pantryAdded + outcome.pantryToppedUp > 0;
          if (touchedPantry) {
            await ref.read(inventoryRepositoryProvider).refresh();
          }
          if (outcome.pantryTicked > 0) {
            await ref.read(shoppingListRepositoryProvider).refresh();
          }
          if (outcome.pharmacyRestocked > 0) {
            await ref.read(pharmacyRepositoryProvider).refresh();
          }
        },
      ),
    );
