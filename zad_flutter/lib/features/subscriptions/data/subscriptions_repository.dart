/// Recurring charges, offline first.
///
/// Same contract as the pantry: the cache is written before anything is sent,
/// the outbox carries it up, reads are synchronous, and a refresh never drops
/// a row that is still queued. What this adds is the read-back: these rows
/// decide what the budget reserves, so a write that did not land is a budget
/// that is wrong without saying so.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';

/// What marking a charge paid did.
class PaidRenewal {
  /// Creates a receipt.
  const new({required this.subscription, required this.paidFor});

  /// The row as it now reads.
  final Subscription subscription;

  /// The renewal that was paid, or null when the row has no schedule to say
  /// which one it was.
  final DateTime? paidFor;
}

/// Holds the recurring charges.
class SubscriptionsRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required SubscriptionsRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final SubscriptionsRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// The outbox id for a queued write of row [id].
  static String outboxIdFor(String id) => 'subscription:$id';

  /// The outbox id for a queued delete of row [id].
  static String deleteOutboxIdFor(String id) => 'subscription_delete:$id';

  /// Every row on the device, in the order they were cached.
  ///
  /// Synchronous. A row that cannot be read is skipped, not thrown.
  List<Subscription> cached() => <Subscription>[
    for (final raw in _cache.values) ?_read(raw),
  ];

  /// Asks the server and replaces what it answered for, keeping queued rows.
  Future<List<Subscription>> refresh() async {
    final rows = await _remote.fetchAll(userId: _requireUserId());
    final server = rows
        .map(Subscription.fromJson)
        .map((s) => s.markPending(pending: false))
        .toList();
    final serverIds = server.map((s) => s.id).toSet();

    // A row still queued is a write the customer was told was saved, and a
    // row with a queued delete must not come back because the server still
    // has it.
    final queuedDeletes = _outbox()
        .entries(includeDead: false)
        .where((e) => e.kind == OutboxKind.deleteSubscription)
        .map((e) => e.payload['id'] as String)
        .toSet();

    final stale = cached()
        .where((s) => !s.isPending && !serverIds.contains(s.id))
        .map((s) => s.id);
    await _cache.deleteAll(stale);

    final pendingIds = cached()
        .where((s) => s.isPending)
        .map((s) => s.id)
        .toSet();
    await _cache.putAll(<String, String>{
      for (final s in server)
        if (!pendingIds.contains(s.id) && !queuedDeletes.contains(s.id))
          s.id: jsonEncode(s.toCacheJson()),
    });

    return cached();
  }

  /// Adds a charge. [renewsOn] is written both as an ISO date and as its day
  /// of the month, the way the Kotlin form writes it, so the server's resolver
  /// has its clearest source.
  Future<Subscription> add({
    required String title,
    required double amount,
    required BillingCycle cycle,
    DateTime? renewsOn,
    String? category,
    String type = SubscriptionType.subscription,
    String? provider,
  }) async {
    final sub = Subscription(
      id: _newId(),
      userId: _requireUserId(),
      title: title.trim(),
      amount: amount,
      renewalDate: renewsOn == null ? null : isoDate(renewsOn),
      dueDay: renewsOn?.day,
      billingCycle: cycle.wireName,
      category: category,
      type: type,
      provider: provider,
      isPending: true,
    );
    await _save(sub);
    return sub;
  }

  /// Writes a changed row.
  Future<Subscription> update(Subscription sub) async {
    final pending = sub.markPending(pending: true);
    await _save(pending);
    return pending;
  }

  /// Starts or stops a charge. A stopped one is no longer reserved.
  Future<Subscription?> setActive(String id, {required bool active}) async {
    final current = _byId(id);
    if (current == null) return null;
    return await update(current.copyWith(isActive: active));
  }

  /// Removes a charge.
  Future<void> remove(String id) async {
    if (_byId(id) == null) return;
    await _cache.delete(id);
    await _outbox().enqueue(
      id: deleteOutboxIdFor(id),
      kind: OutboxKind.deleteSubscription,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Moves a charge past the renewal it just paid.
  ///
  /// The renewal paid is the one the budget is reserving right now — the
  /// server's next renewal as of [today]. Without moving past it the same
  /// money is counted twice until that date goes by: once as the expense the
  /// customer just recorded, once as committed. The Kotlin app stepped from
  /// the stored `renewal_date`, which can be months stale; this steps from
  /// the date the server itself would name.
  ///
  /// The new date is written as ISO. One consequence, shared with Kotlin and
  /// accepted: a monthly charge on the 31st paid in a short month is stored
  /// as the 28th/30th, and the server's ISO branch takes its day from the
  /// stored date, so it renews on that day from then on. The schema has no
  /// way to say "the 28th, anchored on the 31st".
  ///
  /// An instalment titled "(3 أقساط)" counts down, and the last one ends the
  /// plan — the Kotlin convention.
  Future<PaidRenewal?> markPaid(String id, {required DateTime today}) async {
    final current = _byId(id);
    if (current == null) return null;

    final due = current.nextRenewalFrom(today);
    final day = anchorDayOf(
      renewalDate: current.renewalDate,
      dueDay: current.dueDay,
    );
    final after = due == null || day == null
        ? null
        : step(due, cycle: current.cycle, anchorDay: day);

    final instalment = afterInstalmentPaid(current.title);
    final next = current.copyWith(
      title: instalment.title,
      isActive: instalment.stillRunning ? null : false,
      renewalDate: after == null ? null : isoDate(after),
      dueDay: after?.day,
    );
    return PaidRenewal(subscription: await update(next), paidFor: due);
  }

  /// Sends one queued write, and refuses to believe it until it reads back.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) {
      throw StateError('zad_subscriptions has no row ${entry.payload['id']}');
    }
    _verify(sent: entry.payload, stored: stored);

    // The server's row wins in the cache — unless the customer has changed
    // the row again since this entry was queued, in which case the newer
    // write is still waiting and the screen should keep showing it.
    // Compared encoded: entries are decoded afresh on every read, so two maps
    // holding the same payload are never identical objects.
    final id = stored['id'] as String;
    final sent = jsonEncode(entry.payload);
    final superseded = _outbox()
        .entries(includeDead: false)
        .any((e) => e.id == outboxIdFor(id) && jsonEncode(e.payload) != sent);
    if (superseded) return;
    final confirmed = Subscription.fromJson(stored).markPending(pending: false);
    await _cache.put(id, jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued delete.
  Future<void> sendQueuedDelete(OutboxEntry entry) =>
      _remote.remove(entry.payload['id'] as String);

  /// Forgets every row. Called on sign-out.
  Future<void> clear() => _cache.clear();

  Future<void> _save(Subscription sub) async {
    // One entry per row, so editing twice before the queue drains sends the
    // corrected row rather than both in order.
    //
    // Queued *before* the cache is written. A send of this row's previous
    // version may be settling right now, and [sendQueued] only leaves the
    // cache alone if it can see a newer entry queued; cache-first left a gap
    // in which it could not, and it wrote the older server row over the edit
    // (seen with "mark paid" straight after "add").
    await _outbox().enqueue(
      id: outboxIdFor(sub.id),
      kind: OutboxKind.upsertSubscription,
      payload: sub.toUpsertJson(),
    );
    await _cache.put(sub.id, jsonEncode(sub.toCacheJson()));
  }

  Subscription? _byId(String id) => _read(_cache.get(id) ?? '');

  /// The columns that change what the budget reserves, compared as sent.
  static void _verify({
    required Map<String, dynamic> sent,
    required Map<String, dynamic> stored,
  }) {
    final wantAmount = (sent['amount'] as num).toDouble();
    final gotAmount = (stored['amount'] as num?)?.toDouble();
    if (gotAmount == null || (gotAmount - wantAmount).abs() >= 0.005) {
      throw StateError('amount read back as $gotAmount, wanted $wantAmount');
    }
    for (final column in const <String>[
      'is_active',
      'renewal_date',
      'due_day',
      'billing_cycle',
    ]) {
      if (stored[column] != sent[column]) {
        throw StateError(
          '$column read back as ${stored[column]}, wanted ${sent[column]}',
        );
      }
    }
  }

  static Subscription? _read(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Subscription.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to write a subscription for');
    }
    return id;
  }
}

/// `YYYY-MM-DD` for a civil date.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
