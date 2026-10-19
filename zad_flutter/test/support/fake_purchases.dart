// The purchase door for tests: a stand-in for `zad_record_purchase` that keeps
// what it was sent and answers what the test says.

import 'dart:io';

import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/shared/purchases/data/purchases_remote.dart';
import 'package:zad/shared/purchases/data/purchases_repository.dart';
import 'package:zad/shared/purchases/domain/purchase.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';

/// `zad_record_purchase`, as far as a client test needs it.
class FakePurchasesRemote implements PurchasesRemote {
  /// Creates a server; [online] false answers every call with no network.
  new({this.online = true});

  /// Whether calls reach it.
  bool online;

  /// Every purchase sent, in order — retries included.
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

  /// The answer to the next call, or null for a recorded purchase counted
  /// from its lines (each pantry line added, each pharmacy line restocked).
  Map<String, dynamic>? Function(Map<String, dynamic> purchase)? answer;

  /// The expense rows the server holds, by id.
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};

  /// The lines of the last purchase sent.
  List<Map<String, dynamic>> get lastLines => <Map<String, dynamic>>[
    for (final l in sent.last['lines'] as List<Object?>)
      Map<String, dynamic>.from(l! as Map),
  ];

  @override
  Future<Map<String, dynamic>> record(Map<String, dynamic> purchase) async {
    if (!online) throw const SocketException('offline');
    sent.add(purchase);
    final custom = answer?.call(purchase);
    if (custom != null) return custom;

    final lines = purchase['lines'] as List<Object?>? ?? const <Object?>[];
    int count(String to) =>
        lines.where((l) => l is Map && l['to'] == to).length;
    final id = (purchase['merge_with'] ?? purchase['id']) as String;
    rows[id] = <String, dynamic>{
      'id': id,
      'user_id': 'user-1',
      'amount': purchase['amount'],
      'title': purchase['title'],
      'category': purchase['category'],
      'wallet': purchase['wallet'],
      'merchant_name': purchase['merchant_name'],
      'source_type': purchase['source_type'],
      'created_at': purchase['spent_at'],
      'txn_kind': 'expense',
      'is_expense': true,
    };
    return <String, dynamic>{
      'ok': true,
      'status': purchase['merge_with'] == null ? 'recorded' : 'merged',
      'purchase_id': purchase['id'],
      'transaction_id': id,
      'pantry': <String, dynamic>{
        'added': count('pantry'),
        'topped_up': 0,
        'ticked': 0,
      },
      'pharmacy': <String, dynamic>{'restocked': count('pharmacy')},
      'prices': <String, dynamic>{'reported': 0},
      'skipped': <Object?>[],
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchTransaction(String id) async => rows[id];
}

/// A purchase door over [outbox], whose flush is [flush] — by default the
/// outbox's own, as the runner would call it. [afterRecorded] stands in for
/// the pantry and pharmacy refreshes.
PurchasesRepository purchasesFor({
  required Outbox outbox,
  required TransactionsRepository transactions,
  required PurchasesRemote remote,
  Future<void> Function()? flush,
  Future<void> Function(PurchaseOutcome outcome)? afterRecorded,
  String id = '00000000-0000-4000-8000-000000000001',
  String Function()? newId,
}) => PurchasesRepository(
  remote: remote,
  outbox: () => outbox,
  transactions: transactions,
  flush:
      flush ??
      () async {
        await outbox.flush();
      },
  afterRecorded: afterRecorded ?? (_) async {},
  newId: newId ?? () => id,
);

/// A flush that sends nothing: the purchase stays queued.
Future<void> noFlush() async {}
