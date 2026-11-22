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
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/shared/inventory/data/inventory_remote.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/inventory_rules.dart';
import 'package:zad/shared/inventory/domain/shopping_item.dart';
import 'package:zad/shared/inventory/domain/shortage.dart';

class _FakeInventoryRemote implements InventoryRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  final List<String> removed = <String>[];
  Map<String, dynamic> Function(Map<String, dynamic>)? onUpsert;
  Exception? failWith;

  /// Every intent the door was asked to apply.
  final List<Map<String, dynamic>> intents = <Map<String, dynamic>>[];

  /// What the door answers. A refusal is `{'ok': false, 'reason': ...}`.
  Map<String, dynamic> doorAnswer = <String, dynamic>{'ok': true};

  /// The row the server holds after an intent, by id.
  Map<String, Map<String, dynamic>> held = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> commitMyIntent({
    required String kind,
    required String clientEventId,
    required Map<String, dynamic> payload,
    required DateTime occurredAt,
  }) async {
    if (failWith case final e?) throw e;
    intents.add(<String, dynamic>{
      'kind': kind,
      'client_event_id': clientEventId,
      'payload': payload,
      'occurred_at': occurredAt,
    });
    return doorAnswer;
  }

  @override
  Future<Map<String, dynamic>?> fetchOne(String id) async => held[id];

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
  late Box<String> marksBox;
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
    marksBox = await Hive.openBox<String>('marks$run');
    pantryRemote = _FakeInventoryRemote();
    shoppingRemote = _FakeShoppingRemote();
    ids = 0;

    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.upsertInventory => await pantry.sendQueued(entry),
        OutboxKind.commitInventoryIntent => await pantry.sendQueuedIntent(
          entry,
        ),
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
      clock: () => now,
    );
    shopping = ShoppingListRepository(
      cache: shoppingBox,
      remote: shoppingRemote,
      outbox: () => outbox,
      newId: () => 's${ids++}',
      signedInUserId: () => 'user-1',
      marks: marksBox,
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
    test('is on the device before it is sent, queued as an intent', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2, unit: 'لتر');

      expect(pantry.cached().single.itemName, 'لبن');
      expect(pantry.cached().single.isPending, isTrue);
      expect(queued(OutboxKind.commitInventoryIntent), hasLength(1));
      expect(queued(OutboxKind.upsertInventory), isEmpty);
      expect(item.userId, 'user-1');

      final intent = queued(OutboxKind.commitInventoryIntent).single.payload;
      expect(intent['kind'], 'inventory.added');
      // The row is written under the id the cache already shows it by.
      expect((intent['payload'] as Map)['item_id'], item.id);
      expect((intent['payload'] as Map)['quantity'], 2);
    });

    test('a category outside the eight is sent as «أخرى»', () async {
      await pantry.add(itemName: 'لبن', category: 'ألبان');
      await pantry.add(itemName: 'جبنة', category: 'الألبان');

      final sent = queued(OutboxKind.commitInventoryIntent)
          .map((e) => (e.payload['payload'] as Map)['category'])
          .toList();
      expect(sent, <String>['أخرى', 'الألبان']);
    });

    test('editing a field twice replaces the queued row write', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2);
      await pantry.update(item.copyWith(itemName: 'لبن كامل'));
      await pantry.update(item.copyWith(itemName: 'لبن خالي'));

      expect(queued(OutboxKind.upsertInventory), hasLength(1));
      final row = queued(OutboxKind.upsertInventory).single.payload;
      expect(row['item_name'], 'لبن خالي');
      // Without the count: it must not overwrite one still queued as an intent.
      expect(row.containsKey('quantity'), isFalse);
    });

    test('a changed count is a quantity_set, never a row write', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2);
      await pantry.update(item.copyWith(quantity: 5));

      final intents = queued(OutboxKind.commitInventoryIntent);
      expect(intents, hasLength(2));
      expect(intents.last.payload['kind'], 'inventory.quantity_set');
      expect((intents.last.payload['payload'] as Map)['quantity'], 5);
      expect(queued(OutboxKind.upsertInventory), isEmpty);
      expect(pantry.cached().single.quantity, 5);
    });

    test("never sends family_id — that is the trigger's to decide", () async {
      final item = await pantry.add(itemName: 'لبن');
      await pantry.update(item.copyWith(unit: 'لتر'));

      final row = queued(OutboxKind.upsertInventory).single.payload;
      expect(row.containsKey('family_id'), isFalse);
      expect(row.containsKey('created_at'), isFalse);
      final intent =
          queued(OutboxKind.commitInventoryIntent).single.payload['payload']
              as Map;
      expect(intent.containsKey('family_id'), isFalse);
      expect(intent.containsKey('user_id'), isFalse);
    });

    test(
      'member_id rides the intent only when chosen, and reads back',
      () async {
        await pantry.add(itemName: 'لبن');
        final bare =
            queued(OutboxKind.commitInventoryIntent).single.payload['payload']
                as Map;
        expect(bare.containsKey('member_id'), isFalse);

        final item = await pantry.add(itemName: 'جبنة', memberId: 'm-1');
        final intent =
            queued(OutboxKind.commitInventoryIntent).last.payload['payload']
                as Map;
        expect(intent['member_id'], 'm-1');
        expect(
          pantry.cached().firstWhere((i) => i.id == item.id).memberId,
          'm-1',
        );
        expect(
          InventoryItem.fromJson(<String, dynamic>{
            ...serverRow('x'),
            'member_id': 'm-2',
          }).memberId,
          'm-2',
        );

        await pantry.adjustQuantity(item.id, 1);
        final plus =
            queued(OutboxKind.commitInventoryIntent).last.payload['payload']
                as Map;
        // A top-up lands on the existing row, whose owner is already set.
        expect(plus.containsKey('member_id'), isFalse);
        expect(
          pantry.cached().firstWhere((i) => i.id == item.id).memberId,
          'm-1',
        );
      },
    );

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

  group('what the door would refuse is refused before anything is saved', () {
    Future<void> refused(Future<Object?> write, String reason) async {
      await expectLater(
        write,
        throwsA(
          isA<InventoryRuleViolation>().having(
            (e) => e.reason,
            'reason',
            reason,
          ),
        ),
      );
      expect(outbox.entries(), isEmpty);
      expect(pantry.cached(), isEmpty);
    }

    test('a name of one letter, or of 121', () async {
      await refused(pantry.add(itemName: 'ل'), 'name_invalid');
      await refused(pantry.add(itemName: 'ل' * 121), 'name_invalid');
      await refused(pantry.add(itemName: '   '), 'name_invalid');
    });

    test('a name of 2 and of 120 is fine', () async {
      await pantry.add(itemName: 'لب');
      await pantry.add(itemName: 'ل' * 120);
      expect(queued(OutboxKind.commitInventoryIntent), hasLength(2));
    });

    test('zero, negative and rounds-to-zero quantities', () async {
      await refused(
        pantry.add(itemName: 'لبن', quantity: 0),
        'qty_not_positive',
      );
      await refused(
        pantry.add(itemName: 'لبن', quantity: -1),
        'qty_not_positive',
      );
      await refused(
        pantry.add(itemName: 'لبن', quantity: 0.0004),
        'qty_not_positive',
      );
    });

    test('999 is the most an add takes', () async {
      await pantry.add(itemName: 'لبن', quantity: 999);
      await expectLater(
        pantry.add(itemName: 'رز', quantity: 999.5),
        throwsA(isA<InventoryRuleViolation>()),
      );
      expect(pantry.cached(), hasLength(1));
    });

    test('an expiry before today', () async {
      await refused(
        pantry.add(
          itemName: 'لبن',
          expiryDate: DateTime(now.year, now.month, now.day - 1),
        ),
        'expiry_before_purchase',
      );
      await pantry.add(
        itemName: 'لبن',
        expiryDate: DateTime(now.year, now.month, now.day),
      );
    });

    test('an add by more than 999 onto an existing row', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2);
      await expectLater(
        pantry.adjustQuantity(item.id, 1000),
        throwsA(
          isA<InventoryRuleViolation>().having(
            (e) => e.reason,
            'reason',
            'qty_too_large',
          ),
        ),
      );
      expect(pantry.cached().single.quantity, 2);
    });

    test(
      'a consume above 1000 is refused; up to the stock it is clamped',
      () async {
        final item = await pantry.add(itemName: 'لبن', quantity: 3);
        // Clamped to the 3 that are there, so under the cap.
        await pantry.adjustQuantity(item.id, -5000);
        expect(pantry.cached().single.quantity, 0);
        expect(
          (queued(OutboxKind.commitInventoryIntent).last.payload['payload']
              as Map)['amount'],
          3,
        );
      },
    );

    test('a set above max(20 x current, 100), and a negative one', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 2);
      await expectLater(
        pantry.update(item.copyWith(quantity: 101)),
        throwsA(isA<InventoryRuleViolation>()),
      );
      await pantry.update(item.copyWith(quantity: 100));
      await expectLater(
        pantry.update(item.copyWith(quantity: -1)),
        throwsA(isA<InventoryRuleViolation>()),
      );
      expect(pantry.cached().single.quantity, 100);
    });

    test('a set above 20 x a big count', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 50);
      await pantry.update(item.copyWith(quantity: 1000));
      await expectLater(
        pantry.update(pantry.cached().single.copyWith(quantity: 21000)),
        throwsA(isA<InventoryRuleViolation>()),
      );
    });

    test('the door and the phone agree on the eight categories', () {
      expect(kInventoryDoorCategories, hasLength(8));
      expect(inventoryCategoryFor('البقالة'), 'البقالة');
      expect(inventoryCategoryFor(null), 'أخرى');
      expect(inventoryCategoryFor('الكل'), 'أخرى');
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

  group('«أسرع / أبطأ» (م٣.٢)', () {
    Map<String, dynamic> lastRate() => Map<String, dynamic>.from(
      queued(OutboxKind.commitInventoryIntent)
              .where((e) => e.payload['kind'] == 'inventory.rate_corrected')
              .last
              .payload['payload']
          as Map,
    );

    test('the rate the estimate implies is moved by the tap factor', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 6);

      // 6 over 10 days = 0.6 a day.
      await pantry.correctRate(item.id, daysLeft: 10, faster: true);
      expect(lastRate()['item_id'], item.id);
      expect(lastRate()['rate_per_day'], closeTo(0.6 * kRateTapFactor, 1e-4));

      await pantry.correctRate(item.id, daysLeft: 10, faster: false);
      expect(lastRate()['rate_per_day'], closeTo(0.6 / kRateTapFactor, 1e-4));
    });

    test('nothing to correct, nothing queued', () async {
      final empty = await pantry.add(itemName: 'لبن');
      await pantry.adjustQuantity(empty.id, -1);
      final full = await pantry.add(itemName: 'رز', quantity: 2);
      final before = outbox.entries().length;

      await pantry.correctRate(empty.id, daysLeft: 10, faster: true);
      await pantry.correctRate('nope', daysLeft: 10, faster: true);
      await pantry.correctRate(full.id, daysLeft: 0, faster: true);

      expect(outbox.entries(), hasLength(before));
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

    test('a plus is an add onto the row, a minus is a consume', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 3);
      await pantry.adjustQuantity(item.id, 2);
      await pantry.adjustQuantity(item.id, -1);

      final kinds = queued(OutboxKind.commitInventoryIntent)
          .map((e) => e.payload['kind'])
          .toList();
      expect(kinds, <String>[
        'inventory.added',
        'inventory.added',
        'inventory.consumed',
      ]);
      expect(pantry.cached().single.quantity, 4);
      // Two separate things the customer did: never merged into one.
      final ids = queued(OutboxKind.commitInventoryIntent)
          .map((e) => e.payload['client_event_id'])
          .toSet();
      expect(ids, hasLength(3));
    });

    test('taking nothing off an empty row queues nothing', () async {
      final item = await pantry.add(itemName: 'لبن');
      await pantry.adjustQuantity(item.id, -1);
      final before = outbox.entries().length;

      await pantry.adjustQuantity(item.id, -1);

      expect(outbox.entries(), hasLength(before));
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
      final item = await pantry.add(itemName: 'لبن');
      pantryRemote.held[item.id] = <String, dynamic>{
        ...serverRow(item.id),
        'family_id': 'fam-9',
      };
      await outbox.flush();

      final stored = pantry.cached().single;
      expect(stored.familyId, 'fam-9');
      expect(stored.isPending, isFalse);
      expect(outbox.entries(), isEmpty);
    });

    test('a write still queued behind this one is not blinked over', () async {
      final item = await pantry.add(itemName: 'لبن', quantity: 3);
      await pantry.adjustQuantity(item.id, -1);
      // The server's row after the first intent only.
      pantryRemote.held[item.id] = serverRow(item.id);

      await outbox.flush();

      expect(pantryRemote.intents, hasLength(2));
      // Settled by the last write to land, not flipped back to 3 by the first.
      expect(pantry.cached().single.isPending, isFalse);
    });

    test('a failed send leaves the row queued and pending', () async {
      pantryRemote.failWith = const SocketException('offline');

      await pantry.add(itemName: 'لبن');
      await outbox.flush();

      expect(pantry.cached().single.isPending, isTrue);
      expect(queued(OutboxKind.commitInventoryIntent), hasLength(1));
    });

    test(
      'the door gets the intent with its own event id and the time',
      () async {
        final item = await pantry.add(itemName: 'لبن', quantity: 2);
        pantryRemote.held[item.id] = serverRow(item.id);
        await outbox.flush();

        final sent = pantryRemote.intents.single;
        expect(sent['kind'], 'inventory.added');
        expect(sent['client_event_id'], isNotEmpty);
        expect(sent['occurred_at'], now.toUtc());
      },
    );

    test('a refusal is a dead letter, not silence', () async {
      pantryRemote.doorAnswer = <String, dynamic>{
        'ok': false,
        'reason': 'item_not_found',
      };
      await pantry.add(itemName: 'لبن');

      final report = await outbox.flush();

      expect(report.died, 1);
      final dead = outbox.entries().single;
      expect(dead.state, OutboxState.dead);
      expect(dead.lastError, contains('item_not_found'));
    });

    test(
      'not_authenticated stops the flush without charging an attempt',
      () async {
        pantryRemote.doorAnswer = <String, dynamic>{
          'ok': false,
          'reason': 'not_authenticated',
        };
        await pantry.add(itemName: 'لبن');

        final report = await outbox.flush();

        expect(report.stop, FlushStop.unauthenticated);
        expect(outbox.entries().single.attempts, 0);
      },
    );

    test('a duplicate answer is a success', () async {
      pantryRemote.doorAnswer = <String, dynamic>{
        'ok': true,
        'duplicate': true,
      };
      await pantry.add(itemName: 'لبن');

      final report = await outbox.flush();

      expect(report.sent, 1);
      expect(outbox.entries(), isEmpty);
    });
  });

  group('a queue written by the build before this one', () {
    test('an old upsert_inventory entry is still sent, whole', () async {
      await outbox.enqueue(
        id: 'inventory:old-1',
        kind: OutboxKind.upsertInventory,
        payload: <String, dynamic>{
          'id': 'old-1',
          'user_id': 'user-1',
          'item_name': 'رز',
          'quantity': 4,
        },
      );

      await outbox.flush();

      expect(outbox.entries(), isEmpty);
      expect(pantry.cached().single.itemName, 'رز');
      expect(pantry.cached().single.quantity, 4);
      expect(pantryRemote.intents, isEmpty);
    });

    test(
      'editing a row whose first write is still an old entry keeps the count',
      () async {
        const item = InventoryItem(
          id: 'old-2',
          userId: 'user-1',
          itemName: 'رز',
          quantity: 4,
          isPending: true,
        );
        await pantryBox.put(item.id, jsonEncode(item.toCacheJson()));
        await outbox.enqueue(
          id: 'inventory:old-2',
          kind: OutboxKind.upsertInventory,
          payload: item.toUpsertJson(),
        );

        await pantry.update(item.copyWith(itemName: 'رز مصري'));
        await pantry.adjustQuantity('old-2', 1);

        // Still one whole-row write, carrying the count: nothing was split off
        // into an intent that could reach the server before the row exists.
        expect(queued(OutboxKind.commitInventoryIntent), isEmpty);
        final row = queued(OutboxKind.upsertInventory).single.payload;
        expect(row['item_name'], 'رز مصري');
        expect(row['quantity'], 5);
      },
    );
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

    test('restocking takes the automatic line back off the list', () async {
      // Owner, 2026-09-28: «لما أزود المية مبتتلغيش».
      await shopping.addShortages(<Shortage>[
        shortage('مياه', ShortageReason.outOfStock),
      ]);
      expect(shopping.outstanding().map((i) => i.itemName), <String>['مياه']);

      await shopping.addShortages(const <Shortage>[]);

      expect(shopping.outstanding(), isEmpty);
      expect(queued(OutboxKind.deleteShoppingItem), hasLength(1));
    });

    test('a line the customer wrote stays after restocking', () async {
      await shopping.add(itemName: 'مياه');
      await shopping.addShortages(<Shortage>[
        shortage('مياه', ShortageReason.outOfStock),
      ]);

      await shopping.addShortages(const <Shortage>[]);

      expect(shopping.outstanding().map((i) => i.itemName), <String>['مياه']);
    });

    test('a deleted automatic line stays deleted while still short', () async {
      final water = <Shortage>[shortage('مياه', ShortageReason.outOfStock)];
      final added = await shopping.addShortages(water);
      await shopping.remove(added.single.id);

      final again = await shopping.addShortages(water);

      expect(again, isEmpty);
      expect(shopping.outstanding(), isEmpty);
    });

    test('...and comes back once it runs out again after a restock', () async {
      final water = <Shortage>[shortage('مياه', ShortageReason.outOfStock)];
      final added = await shopping.addShortages(water);
      await shopping.remove(added.single.id);
      await shopping.addShortages(const <Shortage>[]); // restocked

      final again = await shopping.addShortages(water); // out again

      expect(again, hasLength(1));
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
