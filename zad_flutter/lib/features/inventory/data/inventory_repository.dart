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

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';

/// Holds the pantry.
class InventoryRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required InventoryRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final InventoryRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

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
  Future<InventoryItem> add({
    required String itemName,
    int quantity = 1,
    String? unit,
    String? category,
    int? lowStockThreshold,
    DateTime? expiryDate,
  }) async {
    final item = InventoryItem(
      id: _newId(),
      userId: _requireUserId(),
      itemName: itemName.trim(),
      quantity: quantity,
      unit: unit,
      category: category,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
      isPending: true,
    );
    await _save(item);
    return item;
  }

  /// Writes a changed row.
  Future<InventoryItem> update(InventoryItem item) async {
    final pending = item.markPending(pending: true);
    await _save(pending);
    return pending;
  }

  /// Moves a row's count by [delta], never below zero.
  ///
  /// Returns null when there is no such row. Clamping rather than refusing:
  /// "I used the last two" on a row that says one is a customer who is right
  /// about their kitchen and wrong about the number in the app, and the count
  /// they meant is zero.
  Future<InventoryItem?> adjustQuantity(String id, int delta) async {
    final current = _read(_cache.get(id) ?? '');
    if (current == null) return null;

    final next = current.quantity + delta;
    return await update(current.copyWith(quantity: next < 0 ? 0 : next));
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

  /// Sends one queued write. Registered as the outbox's sender for
  /// [OutboxKind.upsertInventory].
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) return;

    // The server's row wins: `family_id` is a trigger's decision and is what
    // decides whether the household sees this at all.
    final confirmed = InventoryItem.fromJson(stored)
        .markPending(pending: false);
    await _cache.put(confirmed.id, jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued delete.
  Future<void> sendQueuedDelete(OutboxEntry entry) =>
      _remote.remove(entry.payload['id'] as String);

  /// Forgets the pantry. Called on sign-out.
  Future<void> clear() => _cache.clear();

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
