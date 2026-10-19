// The smart scanner's receipt (CameraActions) does what the scan sheet does:
// the expense says it came from a receipt and names the shop, the lines go
// into the pantry, and they are reported as crowd prices. Before the
// pre-launch audit (2026-10-11) this path saved the expense with neither the
// shop nor its source and reported no price at all.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/scan/application/camera_actions.dart';
import 'package:zad/shared/budget/data/budget_repository.dart';
import 'package:zad/shared/inventory/data/consumption_observations.dart';
import 'package:zad/shared/inventory/data/inventory_remote.dart';
import 'package:zad/shared/inventory/data/inventory_repository.dart';
import 'package:zad/shared/inventory/data/shopping_list_repository.dart';
import 'package:zad/shared/prices/data/prices_remote.dart';
import 'package:zad/shared/prices/data/prices_repository.dart';
import 'package:zad/shared/purchases/data/purchases_repository.dart';
import 'package:zad/shared/scan/domain/scanned_receipt.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';
import 'package:zad/shared/transactions/data/transactions_remote.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

import '../../support/fake_purchases.dart';

class _Pantry implements InventoryRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll() async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;

  @override
  Future<void> remove(String id) async {}
}

class _Shopping implements ShoppingListRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async =>
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

class _NoSettings implements SettingsRemote {
  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

class _NoBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

class _NoTransactions implements TransactionsRemote {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Object?>.error(const SocketException('offline'));
}

class _NoPrices implements PricesRemote {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Object?>.error(const SocketException('offline'));
}

ScannedReceipt _receipt({String storeName = 'بنده'}) =>
    ScannedReceipt.fromJson(<String, dynamic>{
      'total': 37.5,
      'category': 'البقالة',
      'storeName': storeName,
      'receiptType': 'grocery',
      'items': <Object?>[
        <String, dynamic>{
          'name': 'لبن',
          'price': 12.5,
          'quantity': 2.0,
          'unit': 'لتر',
          'category': 'ألبان',
        },
        <String, dynamic>{
          'name': 'عيش',
          'price': 25.0,
          'quantity': 1.0,
          'unit': 'كيس',
          'category': 'مخبوزات',
        },
      ],
    });

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> pantry;
  late Box<String> shopping;
  late Box<String> outboxBox;
  late Outbox outbox;
  late ProviderContainer container;
  var run = 0;
  final now = DateTime.utc(2026, 10, 11, 9);

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_camera_receipt');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    transactions = await Hive.openBox<String>('transactions$run');
    pantry = await Hive.openBox<String>('pantry$run');
    shopping = await Hive.openBox<String>('shopping$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    outbox = Outbox(box: outboxBox, send: (_) async {}, clock: () => now);
    var ids = 0;
    final txns = TransactionsRepository(
      cache: transactions,
      remote: _NoTransactions(),
      outbox: () => outbox,
      newId: () => 'txn-${ids++}',
      signedInUserId: () => 'user-1',
    );
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
            inventory: pantry,
            shopping: shopping,
            pharmacy: documents,
            subscriptions: documents,
            device: documents,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        outboxProvider.overrideWithValue(outbox),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        transactionsRepositoryProvider.overrideWithValue(txns),
        purchasesRepositoryProvider.overrideWithValue(
          purchasesFor(
            outbox: outbox,
            transactions: txns,
            remote: FakePurchasesRemote(online: false),
            flush: noFlush,
            newId: () => '00000000-0000-4000-8000-00000000000${ids++ % 10}',
          ),
        ),
        inventoryRepositoryProvider.overrideWithValue(
          InventoryRepository(
            cache: pantry,
            remote: _Pantry(),
            outbox: () => outbox,
            newId: () => 'p${ids++}',
            signedInUserId: () => 'user-1',
          ),
        ),
        shoppingListRepositoryProvider.overrideWithValue(
          ShoppingListRepository(
            cache: shopping,
            remote: _Shopping(),
            outbox: () => outbox,
            newId: () => 's${ids++}',
            signedInUserId: () => 'user-1',
          ),
        ),
        consumptionObservationsProvider.overrideWithValue(
          ConsumptionObservations(
            remote: _Readings(),
            outbox: () => outbox,
            newId: () => 'o${ids++}',
            signedInUserId: () => 'user-1',
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(
            cache: documents,
            remote: _NoSettings(),
            outbox: () => outbox,
            signedInUserId: () => 'user-1',
            now: () => now,
          ),
        ),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _NoBudget(),
            signedInUserId: () => 'user-1',
          ),
        ),
        pricesRepositoryProvider.overrideWithValue(
          PricesRepository(
            cache: documents,
            remote: _NoPrices(),
            outbox: () => outbox,
            newId: () => 'r${ids++}',
            signedInUserId: () => 'user-1',
            now: () => now,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> queued(String kind) =>
      outbox.entries().where((e) => e.kind == kind).toList();

  List<Map<String, dynamic>> purchases() => <Map<String, dynamic>>[
    for (final e in queued(OutboxKind.recordPurchase)) e.payload,
  ];

  test('the expense names the shop and says it came from a receipt', () async {
    await container
        .read(cameraActionsProvider.notifier)
        .saveReceipt(_receipt());

    final expense = container
        .read(transactionsRepositoryProvider)
        .allCached()
        .single;
    expect(expense.merchantName, 'بنده');
    expect(expense.sourceType, 'receipt');
    expect(purchases().single['source_type'], 'receipt');
    expect(purchases().single['id'], expense.id);
  });

  test('its lines go with the money in one purchase, priced', () async {
    await container
        .read(cameraActionsProvider.notifier)
        .saveReceipt(_receipt());

    // Not an expense, then a pantry, then prices: one write.
    expect(queued(OutboxKind.insertTransaction), isEmpty);
    expect(queued(OutboxKind.reportPrice), isEmpty);
    expect(queued(OutboxKind.upsertInventory), isEmpty);
    final lines = purchases().single['lines'] as List<Object?>;
    expect(lines.map((l) => (l! as Map)['name']), <String>['لبن', 'عيش']);
    expect((lines.first! as Map)['price'], 12.5);
    expect((lines.first! as Map)['to'], 'pantry');
    expect(purchases().single['merchant_name'], 'بنده');
  });

  test(
    'a household receipt is أدوات منزلية; one with no shop names none',
    () async {
      final actions = container.read(cameraActionsProvider.notifier);
      await actions.saveHouseholdReceipt(_receipt());
      expect(purchases().single['category'], 'أدوات منزلية');

      await actions.saveReceipt(_receipt(storeName: ''));
      expect(purchases(), hasLength(2));
      expect(purchases().last.containsKey('merchant_name'), isFalse);
    },
  );

  test('the bank row for the same payment takes the receipt', () async {
    // The camera never looked for it, so a card receipt was a second expense.
    final bank = ZadTransaction.fromJson(<String, dynamic>{
      'id': 'bank-1',
      'user_id': 'user-1',
      'amount': _receipt().total,
      'title': 'BDC شراء',
      'created_at': now.toIso8601String(),
      'txn_kind': 'expense',
      'is_expense': true,
      'source_type': 'notification_listener',
    });
    await container.read(transactionsRepositoryProvider).holdUnsent(bank);

    await container
        .read(cameraActionsProvider.notifier)
        .saveReceipt(_receipt());

    expect(purchases().single['merge_with'], 'bank-1');
    final rows = container.read(transactionsRepositoryProvider).allCached();
    expect(rows.map((t) => t.id), <String>['bank-1']);
    expect(rows.single.title, 'بنده');
  });
}
