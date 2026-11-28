/// The debts buttons' writes, through the one door (P1.6b): `debt.added`,
/// `debt.updated` and `debt.deleted` by `zad_commit_my_intent`, never a table
/// write. The screen reads its rows itself; only the writes live here.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// Adds a loan. [row] is what the add dialog returns; the door sets the
/// principal to the balance, so `principal_amount` is not sent.
Future<void> addDebt(SupabaseClient client, Map<String, dynamic> row) async {
  await commitMyIntent(
    client,
    kind: 'debt.added',
    // One id per press: a double tap sends two intents, a retry of one is the
    // door's duplicate.
    clientEventId: 'debt_add:${newTraceId()}',
    payload: <String, dynamic>{
      'name': row['name'],
      'remaining_balance': row['remaining_balance'],
      'minimum_payment': row['minimum_payment'],
      'interest_rate': row['interest_rate'],
    },
  );
}

/// Sets what is left on [id], never below zero.
Future<void> setDebtBalance(
  SupabaseClient client,
  String id,
  double left,
) async {
  await commitMyIntent(
    client,
    kind: 'debt.updated',
    // An absolute write, so a fresh id per attempt is safe (see
    // transactions_remote.dart).
    clientEventId: 'debt_pay:$id:${newTraceId()}',
    payload: <String, dynamic>{
      'item_id': id,
      'patch': <String, dynamic>{'remaining_balance': left < 0 ? 0 : left},
    },
  );
}

/// Deletes [id]. Already gone is done.
Future<void> deleteDebt(SupabaseClient client, String id) async {
  try {
    await commitMyIntent(
      client,
      kind: 'debt.deleted',
      clientEventId: 'debt_delete:$id',
      payload: <String, dynamic>{'item_id': id},
    );
  } on ServerRefusal catch (e) {
    if (e.reason != 'item_not_found') rethrow;
  }
}
