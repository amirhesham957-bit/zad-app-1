// The pantry and the shopping list, offline first.
//
// Two properties carry most of the weight here. `zad_inventory` is shared with
// the household — a trigger sets `family_id` — so a refresh must not delete
// rows this account did not create, and the server's copy of a row wins over
// the one the device sent. And the shopping list is the only place in this app
// that adds a line on its own, so the rules that stop it growing are tested as
// hard as the ones that make it work.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/inventory_repository.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/inventory/domain/shortage.dart';

class _FakeInventoryRemote implements InventoryRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  final List<String> removed = <String>[];
  Map<String, dynamic> Function(Map<String, dynamic>)? onUpsert;
  Exception? failWith;

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    if (failWith case final e?) throw e;
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final e?) throw e;
    return onUpsert?.call(row) ?? row;
  }

  @override
  Future<void> remove(String id) async {
    if (failWith case final e?) throw e;
    removed.add(id);
  }
}

class _FakeShoppingRemote implements ShoppingListRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  final List<String> removed = <String>[];
  Exception? failWith;

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    if (failWith case final e?) throw e;
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final e?) throw e;
    return row;
  }

  @override
  Future<void> remove(String id) async {
    if (failWith case final e?) throw e;
    removed.add(id);
  }
}

void main() {
  late Directory dir;
  late Box<String> pantryBox;
  late Box<String> shoppingBox;
  late Box<String> outboxBox;
  late _FakeInventoryRemote pantryRemote;
  late _FakeShoppingRemote shoppingRemote;
  late Outbox outbox;
  late InventoryRepository pantry;
  late ShoppingListRepository shopping;

  final now = DateTime.utc(2026, 9, 20, 9);
  var ids = 0;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_pantry_test');
    Hive.init(dir.path);
    pantryBox = await Hive.openBox<String>('pantry$run');
    shoppingBox = await Hive.openBox<String>('shopping$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    pantryRemote = _FakeInventoryRemote();
    shoppingRemote = _FakeShoppingRemote();
    ids = 0;

    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.upsertInventory => await pantry.sendQueued(entry),
        OutboxKind.deleteInventory => await pantry.sendQueuedDelete(entry),
        OutboxKind.upsertShoppingItem => await shopping.sendQueued(entry),
        OutboxKind.deleteShoppingItem => await shopping.sendQueuedDelete(entry),
        _ => throw StateError('no sender for "${entry.kind}"'),
      },
      clock: () => now,
    );
    pantry = InventoryRepository(
      cache: pantryBox,
      remote: pantryRemote,
      outbox: () => outbox,
      newId: () => 'p${ids++}',
      signedInUserId: () => 'user-1',
    );
    shopping = ShoppingListRepository(
      cache: shoppingBox,
      remote: shoppingRemote,
      outbox: () => outbox,
      newId: () => 's${ids++}',
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> queued(String kind) =>
      outbox.entries().where((e) => e.kind == kind).toList();

  Map<String, dynamic> serverRow(
    String id, {
    String name = 'لبن',
    int quantity = 3,
    String? familyId,
    String userId = 'user-1',
  }) => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'item_name': name,
    'quantity': quantity,
    'unit': 'لتر',
    'category': 'ألبان',
    'family_id': ?familyId,
  };

  group('adding to the pantry', () {
    test('is on the device before it is sent', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2, unit: 'لتر');

      expect(pantry.cached().single.itemName, 'لبن');
      expect(pantry.cached().single.isPending, isTrue);
      expect(queued(OutboxKind.upsertInventory), hasLength(1));
      expect(item.userId, 'user-1');
    });

    test('editing the same row twice replaces the queued write', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2);
      await pantry.update(item.copyWith(quantity: 5));

      // Not both versions in the order they were typed — the corrected row.
      expect(queued(OutboxKind.upsertInventory), hasLength(1));
      expect(queued(OutboxKind.upsertInventory).single.payload['quantity'], 5);
    });

    test("never sends family_id — that is the trigger's to decide", () async {
      await pantry.add(itemName: 'لبن');

      final payload = queued(OutboxKind.upsertInventory).single.payload;
      expect(payload.containsKey('family_id'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
    });

    test('refuses to write with nobody signed in', () async {
      final orphan = InventoryRepository(
        cache: pantryBox,
        remote: pantryRemote,
        outbox: () => outbox,
        newId: () => 'x',
        signedInUserId: () => null,
      );

      await expectLater(orphan.add(itemName: 'لبن'), throwsStateError);
    });
  });

  group('refreshing the pantry', () {
    test('keeps a row that is still queued', () async {
      await pantry.add(itemName: 'زبادي');
      pantryRemote.rows = <Map<String, dynamic>>[serverRow('remote-1')];

      await pantry.refresh();

      // A row the customer was told was saved must not blink out of the list
      // and back in when the queue drains.
      expect(
        pantry.cached().map((i) => i.itemName),
        containsAll(<String>['زبادي', 'لبن']),
      );
    });

    test('drops a settled row the server no longer has', () async {
      pantryRemote.rows = <Map<String, dynamic>>[serverRow('remote-1')];
      await pantry.refresh();
      pantryRemote.rows = <Map<String, dynamic>>[];

      await pantry.refresh();

      expect(pantry.cached(), isEmpty);
    });

    test("keeps the household's rows, not only this account's", () async {
      // The shared pantry. Filtering these out — by user_id, or by treating
      // them as stale — is how a family loses sight of what is in its own
      // kitchen.
      pantryRemote.rows = <Map<String, dynamic>>[
        serverRow('mine'),
        serverRow('theirs', name: 'عيش', familyId: 'fam-1', userId: 'user-2'),
      ];

      final items = await pantry.refresh();

      expect(items, hasLength(2));
      expect(items.firstWhere((i) => i.id == 'theirs').familyId, 'fam-1');
    });

    test('a row that cannot be read is skipped, not thrown', () async {
      await pantryBox.put('broken', 'not json');
      await pantryBox.put('broken2', jsonEncode(<String, dynamic>{'nope': 1}));
      pantryRemote.rows = <Map<String, dynamic>>[serverRow('good')];

      await pantry.refresh();

      expect(pantry.cached().map((i) => i.id), <String>['good']);
    });
  });

  group('changing a count', () {
    test('clamps at zero rather than going negative', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 3);

      final adjusted = await pantry.adjustQuantity(item.id, -5);

      // "I used the last two" on a row that says one is somebody who is right
      // about their kitchen and wrong about the number in the app.
      expect(adjusted?.quantity, 0);
    });

    test('a row that is not there is not an error', () async {
      expect(await pantry.adjustQuantity('nope', -1), isNull);
    });
  });

  group('removing a row', () {
    test('queues the delete so it cannot come back', () async {
      pantryRemote.rows = <Map<String, dynamic>>[serverRow('remote-1')];
      await pantry.refresh();

      await pantry.remove('remote-1');

      expect(pantry.cached(), isEmpty);
      // Without the queued delete, the next refresh would restore it.
      expect(queued(OutboxKind.deleteInventory), hasLength(1));

      await outbox.flush();
      expect(pantryRemote.removed, <String>['remote-1']);
    });
  });

  group('what the server says wins', () {
    test('the row read back replaces what was sent', () async {
      // `family_id` is a trigger's decision, and it is what decides whether
      // the household sees this at all.
      pantryRemote.onUpsert = (row) => <String, dynamic>{
        ...row,
        'family_id': 'fam-9',
      };

      await pantry.add(itemName: 'لبن');
      await outbox.flush();

      final stored = pantry.cached().single;
      expect(stored.familyId, 'fam-9');
      expect(stored.isPending, isFalse);
    });

    test('a failed send leaves the row queued and pending', () async {
      pantryRemote.failWith = const SocketException('offline');

      await pantry.add(itemName: 'لبن');
      await outbox.flush();

      expect(pantry.cached().single.isPending, isTrue);
      expect(queued(OutboxKind.upsertInventory), hasLength(1));
    });
  });

  group('the shopping list adds shortages once', () {
    Shortage shortage(String name, ShortageReason reason) => Shortage(
      item: InventoryItem(
        id: 'i-$name',
        userId: 'user-1',
        itemName: name,
        quantity: 0,
      ),
      reason: reason,
    );

    test('one line per shortage, ranked by the reason', () async {
      final added = await shopping.addShortages(<Shortage>[
        shortage('أرز', ShortageReason.outOfStock),
        shortage('لبن', ShortageReason.runningLow),
      ]);

      expect(added, hasLength(2));
      expect(
        shopping.outstanding().map((i) => i.itemName),
        containsAll(<String>['أرز', 'لبن']),
      );
      expect(
        added.firstWhere((i) => i.itemName == 'أرز').priority,
        ShoppingPriority.high,
      );
      expect(
        added.firstWhere((i) => i.itemName == 'لبن').priority,
        ShoppingPriority.medium,
      );
    });

    test('running it twice adds nothing the second time', () async {
      // Idempotent, because it runs on every pantry refresh. Without this the
      // list grows a line per refresh until it is unusable.
      final shortages = <Shortage>[shortage('أرز', ShortageReason.outOfStock)];

      await shopping.addShortages(shortages);
      final second = await shopping.addShortages(shortages);

      expect(second, isEmpty);
      expect(shopping.outstanding(), hasLength(1));
    });

    test('a name the customer already wrote is left alone', () async {
      await shopping.add(itemName: '  أرز  ', quantity: 4);

      final added = await shopping.addShortages(<Shortage>[
        shortage('أرز', ShortageReason.outOfStock),
      ]);

      // Matched on the folded name, so spacing and case do not smuggle in a
      // second line. And the customer's own quantity is untouched.
      expect(added, isEmpty);
      expect(shopping.outstanding().single.quantity, 4);
    });

    test('two shortages with one name become one line', () async {
      final added = await shopping.addShortages(<Shortage>[
        shortage('لبن', ShortageReason.outOfStock),
        shortage('لبن ', ShortageReason.runningLow),
      ]);

      expect(added, hasLength(1));
    });

    test('a line already bought does not block a new one', () async {
      // Running out again after shopping is the normal case, not a duplicate.
      final line = await shopping.add(itemName: 'أرز');
      await shopping.setPurchased(line.id, purchased: true);

      final added = await shopping.addShortages(<Shortage>[
        shortage('أرز', ShortageReason.outOfStock),
      ]);

      expect(added, hasLength(1));
      expect(shopping.outstanding(), hasLength(1));
    });

    test('it never edits or removes a line somebody put there', () async {
      final mine = await shopping.add(
        itemName: 'أرز',
        quantity: 7,
        estimatedPrice: 40,
      );

      await shopping.addShortages(<Shortage>[
        shortage('أرز', ShortageReason.outOfStock),
        shortage('لبن', ShortageReason.runningLow),
      ]);

      final kept = shopping.cached().firstWhere((i) => i.id == mine.id);
      expect(kept.quantity, 7);
      expect(kept.estimatedPrice, 40);
      expect(shopping.cached(), hasLength(2));
    });

    test('a blank name is never added', () async {
      final added = await shopping.addShortages(<Shortage>[
        shortage('   ', ShortageReason.outOfStock),
      ]);

      expect(added, isEmpty);
    });
  });

  group('the shopping list, otherwise', () {
    test('ticking a line off queues the change', () async {
      final line = await shopping.add(itemName: 'أرز');
      await outbox.flush();

      await shopping.setPurchased(line.id, purchased: true);

      expect(shopping.outstanding(), isEmpty);
      expect(shopping.cached().single.isPurchased, isTrue);
      expect(queued(OutboxKind.upsertShoppingItem), hasLength(1));
    });

    test('removing a line queues the delete', () async {
      final line = await shopping.add(itemName: 'أرز');
      await outbox.flush();

      await shopping.remove(line.id);
      await outbox.flush();

      expect(shopping.cached(), isEmpty);
      expect(shoppingRemote.removed, <String>[line.id]);
    });
  });
}
