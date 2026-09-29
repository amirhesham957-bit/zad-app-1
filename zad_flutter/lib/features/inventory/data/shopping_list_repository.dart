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
/// Two more, from the owner's phone (2026-09-28: «لما أزود المية مبتتلغيش»):
///
/// * a line this added goes away on its own once the pantry is no longer
///   short of it — restocking the water used to leave «مياه» on the list;
/// * a line this added and the customer then deleted stays deleted until the
///   pantry recovers. Before, the next pantry refresh saw the water still out
///   and put it straight back, so it could not be cancelled at all.
///
/// Both need to know which lines were automatic, which the table cannot say,
/// so the device remembers it (`marks`); a line typed by the customer is
/// never touched by either rule.
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
    Box<String>? marks,
  }) : _marks = marks,
       _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final ShoppingListRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// Which lines were added by [addShortages], and which of those the
  /// customer deleted. Null: nothing is remembered, as before.
  final Box<String>? _marks;

  static const String _autoPrefix = 'shopping_auto_line:';
  static const String _dismissedPrefix = 'shopping_auto_dismissed:';

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

  /// Stores a price estimate on a line, so it is not asked for again —
  /// Kotlin's `persistEstimatedPrice`.
  Future<ShoppingItem?> setEstimatedPrice(String id, double price) async {
    final current = _read(_cache.get(id) ?? '');
    if (current == null) return null;
    final next = current
        .copyWith(estimatedPrice: price)
        .markPending(pending: true);
    await _save(next);
    return next;
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
  ///
  /// A line [addShortages] put there is remembered as declined, so the next
  /// pantry refresh does not add it straight back.
  Future<void> remove(String id) async {
    final autoKey = _marks?.get('$_autoPrefix$id');
    if (autoKey != null) {
      await _marks!.delete('$_autoPrefix$id');
      await _marks.put('$_dismissedPrefix$autoKey', '1');
    }
    await _drop(id);
  }

  Future<void> _drop(String id) async {
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
    await _settleAutomatic(shortages);
    final marks = _marks;
    final taken = outstanding().map((i) => shortageKey(i.itemName)).toSet();
    final added = <ShoppingItem>[];

    for (final shortage in shortages) {
      final key = shortageKey(shortage.item.itemName);
      // Guards against both the existing list and two shortages in the same
      // batch resolving to one name.
      if (key.isEmpty || taken.contains(key)) continue;
      if (marks?.get('$_dismissedPrefix$key') != null) continue;
      taken.add(key);

      final item = await add(
        itemName: shortage.item.itemName,
        priority: shortage.priority,
        at: at,
      );
      await marks?.put('$_autoPrefix${item.id}', key);
      added.add(item);
    }

    return added;
  }

  /// Takes back what the pantry no longer needs, and forgets a decline once
  /// the pantry has recovered — running out again later is a new shortage.
  Future<void> _settleAutomatic(List<Shortage> shortages) async {
    final marks = _marks;
    if (marks == null) return;
    final short = <String>{
      for (final s in shortages) shortageKey(s.item.itemName),
    };
    for (final markKey in marks.keys.whereType<String>().toList()) {
      if (markKey.startsWith(_dismissedPrefix)) {
        final key = markKey.substring(_dismissedPrefix.length);
        if (!short.contains(key)) await marks.delete(markKey);
        continue;
      }
      if (!markKey.startsWith(_autoPrefix)) continue;
      final id = markKey.substring(_autoPrefix.length);
      final line = _read(_cache.get(id) ?? '');
      // Gone, or bought: nothing left to take back.
      if (line == null || !line.isOutstanding) {
        await marks.delete(markKey);
        continue;
      }
      if (!short.contains(marks.get(markKey))) {
        await marks.delete(markKey);
        await _drop(id);
      }
    }
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
  Future<void> clear() async {
    await _cache.clear();
    final marks = _marks;
    if (marks == null) return;
    await marks.deleteAll(
      marks.keys.whereType<String>().where(
        (k) => k.startsWith(_autoPrefix) || k.startsWith(_dismissedPrefix),
      ),
    );
  }

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
