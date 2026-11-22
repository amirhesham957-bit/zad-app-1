/// The pantry, offline first.
///
/// Same contract as transactions: the cache is written before anything is
/// sent, the queue carries it up, and the read is synchronous so a screen
/// opens on the pantry rather than on a spinner.
///
/// The one difference worth knowing is who owns a row. `zad_inventory` is
/// shared with the household — a trigger sets `family_id` — so the cache can
/// hold rows this account did not create and must not delete them on a
/// refresh merely because they are not its own.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:uuid/uuid.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/shared/inventory/data/inventory_remote.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/inventory_rules.dart';

/// Holds the pantry.
class InventoryRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required InventoryRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
    DateTime Function()? clock,
  }) : _clock = clock,
       _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final InventoryRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)();

  /// Everything on the device, by name.
  ///
  /// Synchronous. Call it from `build`. A row that cannot be read is skipped
  /// rather than thrown — one unreadable row must not cost the whole pantry.
  List<InventoryItem> cached() {
    final items = <InventoryItem>[];
    for (final raw in _cache.values) {
      final item = _read(raw);
      if (item != null) items.add(item);
    }
    return items..sort((a, b) => a.itemName.compareTo(b.itemName));
  }

  /// Asks the server and replaces what it answered for.
  ///
  /// Queued rows survive. A row the customer has just added is a write they
  /// were told was saved; dropping it because the server has not mentioned it
  /// yet would make it blink out of the list and back in when the queue
  /// drains.
  Future<List<InventoryItem>> refresh() async {
    final rows = await _remote.fetchAll();
    final server = rows
        .map(InventoryItem.fromJson)
        .map((i) => i.markPending(pending: false))
        .toList();
    final serverIds = server.map((i) => i.id).toSet();

    final stale = cached()
        .where((i) => !i.isPending && !serverIds.contains(i.id))
        .map((i) => i.id);
    await _cache.deleteAll(stale);

    await _cache.putAll(<String, String>{
      for (final item in server) item.id: jsonEncode(item.toCacheJson()),
    });

    return cached();
  }

  /// Adds a row: cache first, queue second, network never.
  ///
  /// Queued as an `inventory.added` intent carrying the row's own id, so the
  /// door writes the row under the id the cache already uses. Throws an
  /// [InventoryRuleViolation] — before anything is saved — for a write the door
  /// would refuse.
  Future<InventoryItem> add({
    required String itemName,
    double quantity = 1,
    String? unit,
    String? category,
    double? lowStockThreshold,
    DateTime? expiryDate,
  }) async {
    final userId = _requireUserId();
    final now = _now();
    requireValidAddition(
      name: itemName,
      quantity: quantity,
      expiry: expiryDate,
      today: now,
    );
    final item = InventoryItem(
      id: _newId(),
      userId: userId,
      itemName: itemName.trim(),
      quantity: roundQuantity(quantity).toDouble(),
      unit: unit,
      category: inventoryCategoryFor(category),
      // Chosen here rather than left to the server's trigger, so the row
      // reads right while it is still queued (ZAD_PLAN ١٠.١ slice 3). The
      // door does not take it: the server's own default replaces it on the
      // read-back.
      lowStockThreshold:
          lowStockThreshold ?? defaultLowStockThreshold(quantity, unit),
      expiryDate: expiryDate,
      isPending: true,
    );
    await _cache.put(item.id, jsonEncode(item.toCacheJson()));
    await _queueIntent('inventory.added', item.id, <String, dynamic>{
      'item_id': item.id,
      'item_name': item.itemName,
      'quantity': item.quantity,
      'category': item.category,
      if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
      if (expiryDate != null) 'expiry_date': _day(expiryDate),
    }, now);
    return item;
  }

  /// Writes a changed row.
  ///
  /// A changed count goes through the door as `inventory.quantity_set`. What
  /// the door has no intent for — name, unit, expiry, restock mode — is still a
  /// row upsert, sent without the count so it cannot overwrite a count intent
  /// still in the queue. Throws an [InventoryRuleViolation] before saving
  /// anything.
  Future<InventoryItem> update(InventoryItem item) async {
    final before = _read(_cache.get(item.id) ?? '');
    final pending = item.markPending(pending: true);

    // A row still queued in the old whole-row form keeps going that way: its
    // count is in that entry, and replacing it with a count-less one would
    // lose the row's first write.
    if (before == null || _legacyUpsertQueued(item.id)) {
      await _save(pending);
      return pending;
    }

    final countChanged =
        roundQuantity(item.quantity) != roundQuantity(before.quantity);
    if (countChanged) {
      requireValidQuantitySet(item.quantity, current: before.quantity);
    }
    final now = _now();
    final fieldsChanged = _fieldsOf(before) != _fieldsOf(pending);
    if (item.itemName.trim().length < kInventoryNameMin ||
        item.itemName.trim().length > kInventoryNameMax) {
      throw const InventoryRuleViolation('name_invalid');
    }

    await _cache.put(item.id, jsonEncode(pending.toCacheJson()));
    if (fieldsChanged) {
      await _outbox().enqueue(
        id: 'inventory:${item.id}',
        kind: OutboxKind.upsertInventory,
        payload: pending.toUpsertJson()..remove('quantity'),
      );
    }
    if (countChanged) {
      await _queueIntent('inventory.quantity_set', item.id, <String, dynamic>{
        'item_id': item.id,
        'quantity': roundQuantity(item.quantity),
      }, now);
    }
    return pending;
  }

  /// Moves a row's count by [delta], never below zero.
  ///
  /// Returns null when there is no such row. Clamping rather than refusing:
  /// "I used the last two" on a row that says one is a customer who is right
  /// about their kitchen and wrong about the number in the app, and the count
  /// they meant is zero.
  ///
  /// A plus is an `inventory.added` onto the row's own id (the door adds to a
  /// household row it is given); a minus is `inventory.consumed`. Throws an
  /// [InventoryRuleViolation] for a delta beyond what the door takes.
  Future<InventoryItem?> adjustQuantity(String id, num delta) async {
    final current = _read(_cache.get(id) ?? '');
    if (current == null) return null;
    if (delta == 0) return current;

    final next = current.quantity + delta;
    final moved = current.copyWith(quantity: next < 0 ? 0 : next);
    if (_legacyUpsertQueued(id)) return await update(moved);

    final now = _now();
    if (delta > 0) {
      requireValidAddition(name: current.itemName, quantity: delta, today: now);
      await _cache.put(
        id,
        jsonEncode(moved.markPending(pending: true).toCacheJson()),
      );
      await _queueIntent('inventory.added', id, <String, dynamic>{
        'item_id': id,
        'item_name': current.itemName,
        'quantity': roundQuantity(delta),
        'category': inventoryCategoryFor(current.category),
      }, now);
    } else {
      // Only what is there can be taken: the clamp, said to the door too.
      final amount = -delta > current.quantity ? current.quantity : -delta;
      if (amount <= 0) return current;
      requireValidConsumption(amount);
      await _cache.put(
        id,
        jsonEncode(moved.markPending(pending: true).toCacheJson()),
      );
      await _queueIntent('inventory.consumed', id, <String, dynamic>{
        'item_id': id,
        'amount': roundQuantity(amount),
      }, now);
    }
    return _read(_cache.get(id) ?? '');
  }

  /// Removes a row from the pantry.
  Future<void> remove(String id) async {
    final item = _read(_cache.get(id) ?? '');
    if (item == null) return;

    await _cache.delete(id);
    await _outbox().enqueue(
      id: 'inventory_delete:$id',
      kind: OutboxKind.deleteInventory,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Sends one queued row write, in the whole-row form. Registered as the
  /// outbox's sender for [OutboxKind.upsertInventory].
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) return;

    // The server's row wins: `family_id` is a trigger's decision and is what
    // decides whether the household sees this at all.
    final confirmed = InventoryItem.fromJson(stored)
        .markPending(pending: false);
    await _cache.put(confirmed.id, jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued intent through the door. Registered as the outbox's
  /// sender for [OutboxKind.commitInventoryIntent].
  ///
  /// The door answers a refusal as data. It is thrown here as a
  /// [ServerRefusal] so the outbox keeps a dead letter: a count the customer
  /// was told went in must not vanish quietly. `duplicate` is a success — the
  /// first send landed and only its answer was lost.
  Future<void> sendQueuedIntent(OutboxEntry entry) async {
    final p = entry.payload;
    final payload = Map<String, dynamic>.from(p['payload'] as Map);
    final answer = await _remote.commitMyIntent(
      kind: p['kind'] as String,
      clientEventId: p['client_event_id'] as String,
      payload: payload,
      occurredAt: DateTime.parse(p['occurred_at'] as String),
    );
    if (answer['ok'] != true) {
      final reason = (answer['reason'] as String?) ?? 'unknown';
      // The session, not the write, is what is wrong: no attempt charged.
      if (reason == 'not_authenticated') throw AuthException(reason);
      throw ServerRefusal('zad_commit_my_intent', reason);
    }

    final id = payload['item_id'] as String;
    // Another write for the same row is still queued: the server's row does
    // not include it yet, so putting that row in the cache would blink the
    // screen back to an older count. The last write to land settles it.
    if (_otherWritesQueued(id, except: entry.id)) return;

    final stored = await _remote.fetchOne(id);
    if (stored == null) return;
    final confirmed = InventoryItem.fromJson(stored)
        .markPending(pending: false);
    await _cache.put(confirmed.id, jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued delete.
  Future<void> sendQueuedDelete(OutboxEntry entry) =>
      _remote.remove(entry.payload['id'] as String);

  /// Forgets the pantry. Called on sign-out.
  Future<void> clear() => _cache.clear();

  Future<void> _queueIntent(
    String kind,
    String itemId,
    Map<String, dynamic> payload,
    DateTime occurredAt,
  ) {
    final eventId = _newId();
    return _outbox().enqueue(
      id: 'inventory_intent:$eventId',
      kind: OutboxKind.commitInventoryIntent,
      payload: <String, dynamic>{
        'kind': kind,
        'client_event_id': eventId,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'payload': payload,
      },
    );
  }

  /// A whole-row write is still queued for [id] — one with a count in it, which
  /// only a build from before the intents could have made. The count-less
  /// upserts this build queues do not count.
  bool _legacyUpsertQueued(String id) => _outbox().entries().any(
    (e) =>
        e.id == 'inventory:$id' &&
        e.kind == OutboxKind.upsertInventory &&
        e.payload.containsKey('quantity'),
  );

  bool _otherWritesQueued(String id, {required String except}) =>
      _outbox().entries(includeDead: false).any((e) {
        if (e.id == except) return false;
        if (e.kind == OutboxKind.upsertInventory) return e.payload['id'] == id;
        if (e.kind == OutboxKind.commitInventoryIntent) {
          return (e.payload['payload'] as Map)['item_id'] == id;
        }
        return false;
      });

  /// Everything about a row except its count — what an upsert still carries.
  static String _fieldsOf(InventoryItem i) =>
      jsonEncode(i.toUpsertJson()..remove('quantity'));

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save(InventoryItem item) async {
    await _cache.put(item.id, jsonEncode(item.toCacheJson()));
    // One entry per row id, so editing the same item twice before the queue
    // drains sends the corrected row rather than both versions in order.
    await _outbox().enqueue(
      id: 'inventory:${item.id}',
      kind: OutboxKind.upsertInventory,
      payload: item.toUpsertJson(),
    );
  }

  static InventoryItem? _read(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return InventoryItem.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to write a pantry row for');
    }
    return id;
  }
}

/// The pantry, offline first.
final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) {
      final store = ref.watch(localStoreProvider);
      return InventoryRepository(
        cache: store.inventory,
        remote: SupabaseInventoryRemote(ref.watch(supabaseClientProvider)),
        outbox: () => ref.read(outboxProvider),
        newId: const Uuid().v4,
        signedInUserId: ref.watch(signedInUserIdProvider),
      );
    });
