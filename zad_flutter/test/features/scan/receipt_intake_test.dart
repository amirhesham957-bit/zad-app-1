// A grocery receipt fills the pantry and closes the shopping-list loop — the
// job Kotlin's InventoryFlowEngine.injectScannedItems does, by the same name
// rules. Pinned here: what matches what, that duplicates and double matches
// add once, that the customer's unticked lines stay out, that the consumption
// learner gets a reading before *and* after, and that the expense survives a
// pantry that fails.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/inventory/data/consumption_observations.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/inventory_repository.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/inventory/domain/inventory_item.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/inventory/domain/shopping_item.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

InventoryItem _pantry(String id, String name, int qty) =>
    InventoryItem(id: id, userId: 'u', itemName: name, quantity: qty);

ShoppingItem _list(String id, String name, {bool bought = false}) =>
    ShoppingItem(id: id, userId: 'u', itemName: name, isPurchased: bought);

IntakeLine _line(String name, [int qty = 1]) =>
    IntakeLine(name: name, quantity: qty);

class _Camera implements ReceiptCamera {
  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async =>
      Uint8List.fromList(<int>[1]);
}

class _Scanner implements ReceiptScanner {
  Map<String, dynamic> answer = <String, dynamic>{};

  @override
  Future<ScannedReceipt> scan({
    required String userId,
    required Uint8List image,
  }) async => ScannedReceipt.fromJson(answer);
}

class _Accepting implements InventoryRemote, ShoppingListRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({String? userId}) async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;

  @override
  Future<void> remove(String id) async {}
}

class _Readings implements ObservationRemote {
  @override
  Future<Object?> record({
    required String userId,
    required String item,
    required num quantity,
    required String source,
  }) async => <String, dynamic>{'samples': 0};
}

class _NoTransactions implements TransactionsRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

void main() {
  group('the name rules, as Kotlin has them', () {
    test('alef forms, taa marbuta, alef maqsura and the article', () {
      expect(normalizeItemName('  الألبان المعلبة '), 'البان معلبه');
      expect(itemNamesMatch('لبن جهينة', 'اللبن جهينه'), isTrue);
      expect(itemNamesMatch('مكرونة', 'المكرونه'), isTrue);
    });

    test('shared words: all of the shorter name, up to two', () {
      expect(itemNamesMatch('أرز', 'أرز بسمتي'), isTrue);
      expect(itemNamesMatch('زيت عباد الشمس', 'زيت عباد'), isTrue);
      expect(itemNamesMatch('زيت زيتون', 'زيت ذرة'), isFalse);
      // Words of two letters or fewer never count.
      expect(itemNamesMatch('شاي', 'شاي لبتون'), isTrue);
      expect(itemNamesMatch('بن', 'بن برازيلي'), isFalse);
    });

    test('a receipt count is whole and at least one', () {
      expect(wholeCount(0.4), 1);
      expect(wholeCount(1.5), 2);
      expect(wholeCount(3), 3);
    });
  });

  group('planning', () {
    test('existing rows grow, new names are added, the list is ticked', () {
      final plan = planIntake(
        lines: <IntakeLine>[_line('لبن', 2), _line('عيش بلدي')],
        pantry: <InventoryItem>[_pantry('p1', 'اللبن', 1)],
        shopping: <ShoppingItem>[
          _list('s1', 'عيش'),
          _list('s2', 'عيش', bought: true),
          _list('s3', 'جبنة'),
        ],
      );

      expect(plan.increments.single.item.id, 'p1');
      expect(plan.increments.single.add, 2);
      expect(plan.additions.single.name, 'عيش بلدي');
      // Open lines only; a line already bought stays as it is.
      expect(plan.bought.map((s) => s.id), <String>['s1']);
    });

    test('two lines for one product are one increment', () {
      final plan = planIntake(
        lines: <IntakeLine>[_line('لبن'), _line('اللبن', 2)],
        pantry: <InventoryItem>[_pantry('p1', 'لبن', 1)],
        shopping: const <ShoppingItem>[],
      );
      expect(plan.increments.single.add, 3);
    });

    test('two printings that both match one row add to it once each', () {
      // They do not match each other ("زيت عباد" / "زيت ذرة"), but the pantry
      // row "زيت" matches both. Kotlin would write the row twice and keep the
      // second.
      final plan = planIntake(
        lines: <IntakeLine>[_line('زيت عباد'), _line('زيت ذرة', 2)],
        pantry: <InventoryItem>[_pantry('p1', 'زيت', 0)],
        shopping: const <ShoppingItem>[],
      );
      expect(plan.increments, hasLength(1));
      expect(plan.increments.single.add, 3);
    });
  });

  group('saving a grocery receipt', () {
    late Directory dir;
    late Box<String> documents;
    late Box<String> transactions;
    late Box<String> inventoryBox;
    late Box<String> shoppingBox;
    late Box<String> outboxBox;
    late _Scanner scanner;
    late Outbox outbox;
    late InventoryRepository inventory;
    late ShoppingListRepository shopping;
    var ids = 0;
    var run = 0;
    final now = DateTime.parse('2026-09-21T09:00:00Z');

    setUp(() async {
      run++;
      ids = 0;
      dir = await Directory.systemTemp.createTemp('zad_intake_test');
      Hive.init(dir.path);
      documents = await Hive.openBox<String>('documents$run');
      transactions = await Hive.openBox<String>('transactions$run');
      inventoryBox = await Hive.openBox<String>('inventory$run');
      shoppingBox = await Hive.openBox<String>('shopping$run');
      outboxBox = await Hive.openBox<String>('outbox$run');
      scanner = _Scanner()
        ..answer = <String, dynamic>{
          'total': 120,
          'category': 'البقالة',
          'storeName': 'كازيون',
          'receiptType': 'grocery',
          'items': <Object?>[
            <String, dynamic>{'name': 'لبن', 'quantity': 2, 'unit': 'لتر'},
            <String, dynamic>{'name': 'عيش بلدي', 'quantity': 1},
            <String, dynamic>{'name': 'شيبسي', 'quantity': 3},
          ],
        };
      // Never sent in these tests: nothing flushes the queue.
      outbox = Outbox(box: outboxBox, send: (_) async {}, clock: () => now);
      inventory = InventoryRepository(
        cache: inventoryBox,
        remote: _Accepting(),
        outbox: () => outbox,
        newId: () => 'inv-${ids++}',
        signedInUserId: () => 'user-1',
      );
      shopping = ShoppingListRepository(
        cache: shoppingBox,
        remote: _Accepting(),
        outbox: () => outbox,
        newId: () => 'shop-${ids++}',
        signedInUserId: () => 'user-1',
      );
      await inventory.add(itemName: 'اللبن', unit: 'لتر');
      await shopping.add(itemName: 'عيش');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    ProviderContainer container({bool pantryBreaks = false}) =>
        ProviderContainer(
          overrides: [
            nowProvider.overrideWithValue(() => now),
            signedInUserIdProvider.overrideWithValue(() => 'user-1'),
            outboxProvider.overrideWithValue(outbox),
            receiptCameraProvider.overrideWithValue(_Camera()),
            receiptScannerProvider.overrideWithValue(scanner),
            transactionsRepositoryProvider.overrideWithValue(
              TransactionsRepository(
                cache: transactions,
                remote: _NoTransactions(),
                outbox: () => outbox,
                newId: () => 'txn-${ids++}',
                signedInUserId: () => 'user-1',
              ),
            ),
            budgetRepositoryProvider.overrideWithValue(
              BudgetRepository(
                cache: documents,
                remote: _OfflineBudget(),
                signedInUserId: () => 'user-1',
              ),
            ),
            if (pantryBreaks)
              inventoryRepositoryProvider.overrideWith(
                (ref) => throw StateError('the pantry is not there'),
              )
            else
              inventoryRepositoryProvider.overrideWithValue(inventory),
            shoppingListRepositoryProvider.overrideWithValue(shopping),
            consumptionObservationsProvider.overrideWithValue(
              ConsumptionObservations(
                remote: _Readings(),
                outbox: () => outbox,
                newId: () => 'obs-${ids++}',
                signedInUserId: () => 'user-1',
              ),
            ),
          ],
        );

    Future<ScanController> scanned(ProviderContainer c) async {
      final controller = c.read(scanControllerProvider.notifier);
      await controller.scan(ReceiptImageSource.camera);
      expect(c.read(scanControllerProvider).offersPantry, isTrue);
      return controller;
    }

    List<num> readings(String item) => <num>[
      for (final e in outbox.entries())
        if (e.kind == OutboxKind.recordObservation && e.payload['item'] == item)
          e.payload['qty'] as num,
    ];

    test(
      'ticked lines go in, unticked ones stay out, the list closes',
      () async {
        final c = container();
        addTearDown(c.dispose);
        final controller = await scanned(c);

        controller.toggleItem(2); // no crisps in this pantry
        expect(await controller.saveAsTransaction(), isTrue);

        final rows = {
          for (final i in inventory.cached()) i.itemName: i.quantity,
        };
        expect(rows, <String, int>{'اللبن': 3, 'عيش بلدي': 1});
        expect(shopping.cached().single.isPurchased, isTrue);

        final intake = c.read(scanControllerProvider).lastIntake!;
        expect((intake.added, intake.toppedUp, intake.ticked), (1, 1, 1));
      },
    );

    test('the learner hears the level before and after the purchase', () async {
      final c = container();
      addTearDown(c.dispose);
      await (await scanned(c)).saveAsTransaction();

      // 1 on the shelf before, 3 after: the drop since the last reading is
      // counted, not swallowed by the rise.
      expect(readings('اللبن'), <num>[1, 3]);
      expect(readings('عيش بلدي'), <num>[1]);
    });

    test('with the switch off, only the money is recorded', () async {
      final c = container();
      addTearDown(c.dispose);
      final controller = await scanned(c);

      controller.setAddToPantry(value: false);
      await controller.saveAsTransaction();

      expect(inventory.cached().single.quantity, 1);
      expect(shopping.cached().single.isPurchased, isFalse);
      expect(c.read(scanControllerProvider).lastIntake, isNull);
    });

    test('a restaurant bill never reaches the pantry', () async {
      scanner.answer = <String, dynamic>{
        ...scanner.answer,
        'receiptType': 'general',
      };
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(scanControllerProvider.notifier);
      await controller.scan(ReceiptImageSource.camera);

      expect(c.read(scanControllerProvider).offersPantry, isFalse);
      await controller.saveAsTransaction();
      expect(inventory.cached(), hasLength(1));
    });

    test('a pantry that fails does not cost the expense', () async {
      final c = container(pantryBreaks: true);
      addTearDown(c.dispose);

      expect(await (await scanned(c)).saveAsTransaction(), isTrue);
      expect(c.read(transactionsRepositoryProvider).allCached(), hasLength(1));
      expect(c.read(scanControllerProvider).lastIntake?.failed, isTrue);
    });
  });
}
