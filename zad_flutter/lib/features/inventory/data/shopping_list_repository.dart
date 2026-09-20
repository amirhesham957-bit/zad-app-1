/// The shopping list, offline first — and the one place the app adds a line
/// on its own.
///
/// Automatic additions are the risky part, so the rules are narrow and stated
/// here rather than spread through a screen:
///
/// * it only ever **adds**, never edits or removes a line somebody put there;
/// * it adds a name at most once, because `zad_shopping_list` has no column
///   saying where a line came from, so a duplicate is indistinguishable from
///   the customer having asked for two;
/// * a line already bought does not block a new one — running out again after
///   shopping is the normal case, not a duplicate;
/// * and it is idempotent, so running it on every pantry refresh cannot grow
///   the list.
///
/// That last one matters more than it looks. The Kotlin app has no automatic
/// path at all — every `addShoppingItem` call site is a button — so this is
/// new behaviour, and new automatic writes are exactly what
/// `detectSubscriptions()` had to be walked back for.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

/// Holds the shopping list.
class ShoppingListRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required ShoppingListRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final ShoppingListRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// The key two lines are considered the same under.
  ///
  /// Whitespace-folded and case-insensitive, and nothing more. Arabic
  /// normalisation — أ/ا, ة/ه, stripping diacritics — is deliberately not done
  /// here: it would make "بنّ" and "بن" the same line, and those are coffee
  /// and a son. The pantry name and the list name come from the same places
  /// (the scanner, the customer), so an exact fold catches the real case.
  static String shortageKey(String itemName) =>
      itemName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Everything on the device, newest first.
  List<ShoppingItem> cached() {
    final items = <ShoppingItem>[];
    for (final raw in _cache.values) {
      final item = _read(raw);
      if (item != null) items.add(item);
    }
    return items..sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null || bt == null) return a.itemName.compareTo(b.itemName);
      return bt.compareTo(at);
    });
  }

  /// The lines still to buy.
  List<ShoppingItem> outstanding() =>
      cached().where((i) => i.isOutstanding).toList();

  /// Asks the server and replaces what it answered for, keeping queued lines.
  Future<List<ShoppingItem>> refresh() async {
    final rows = await _remote.fetchAll(userId: _requireUserId());
    final server = rows
        .map(ShoppingItem.fromJson)
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

  /// Adds a line the customer asked for.
  Future<ShoppingItem> add({
    required String itemName,
    int quantity = 1,
    double estimatedPrice = 0,
    ShoppingPriority priority = ShoppingPriority.medium,
    String? store,
    DateTime? at,
  }) async {
    final item = ShoppingItem(
      id: _newId(),
      userId: _requireUserId(),
      itemName: itemName.trim(),
      quantity: quantity,
      estimatedPrice: estimatedPrice,
      priority: priority,
      store: store,
      createdAt: at,
      isPending: true,
    );
    await _save(item);
    return item;
  }

  /// Ticks a line off, or back on.
  Future<ShoppingItem?> setPurchased(
    String id, {
    required bool purchased,
  }) async {
    final current = _read(_cache.get(id) ?? '');
    if (current == null) return null;

    final next = current
        .copyWith(isPurchased: purchased)
        .markPending(pending: true);
    await _save(next);
    return next;
  }

  /// Removes a line.
  Future<void> remove(String id) async {
    if (_read(_cache.get(id) ?? '') == null) return;

    await _cache.delete(id);
    await _outbox().enqueue(
      id: 'shopping_delete:$id',
      kind: OutboxKind.deleteShoppingItem,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Puts everything that has run out onto the list, once each.
  ///
  /// Returns the lines it actually added, which is what a screen should
  /// report — "added 3" is worth saying, "added 0" is worth saying nothing
  /// about.
  Future<List<ShoppingItem>> addShortages(
    List<Shortage> shortages, {
    DateTime? at,
  }) async {
    final taken = outstanding().map((i) => shortageKey(i.itemName)).toSet();
    final added = <ShoppingItem>[];

    for (final shortage in shortages) {
      final key = shortageKey(shortage.item.itemName);
      // Guards against both the existing list and two shortages in the same
      // batch resolving to one name.
      if (key.isEmpty || taken.contains(key)) continue;
      taken.add(key);

      added.add(
        await add(
          itemName: shortage.item.itemName,
          priority: shortage.priority,
          at: at,
        ),
      );
    }

    return added;
  }

  /// Sends one queued write.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) return;

    final confirmed = ShoppingItem.fromJson(stored).markPending(pending: false);
    await _cache.put(confirmed.id, jsonEncode(confirmed.toCacheJson()));
  }

  /// Sends one queued delete.
  Future<void> sendQueuedDelete(OutboxEntry entry) =>
      _remote.remove(entry.payload['id'] as String);

  /// Forgets the list. Called on sign-out.
  Future<void> clear() => _cache.clear();

  Future<void> _save(ShoppingItem item) async {
    await _cache.put(item.id, jsonEncode(item.toCacheJson()));
    await _outbox().enqueue(
      id: 'shopping:${item.id}',
      kind: OutboxKind.upsertShoppingItem,
      payload: item.toUpsertJson(),
    );
  }

  static ShoppingItem? _read(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ShoppingItem.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to write a shopping line for');
    }
    return id;
  }
}
