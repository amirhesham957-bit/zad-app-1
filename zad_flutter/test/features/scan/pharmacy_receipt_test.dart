// A pharmacy receipt restocks the pharmacy, the way a grocery receipt fills
// the pantry: the expense first, then the ticked lines — tracked medicines
// topped up through the restock function, new ones started with their count,
// the shopping list closed. Pinned here too: a box whose contents the name
// does not print is not added until the customer counts it, and neither
// kind of receipt reaches the other's shelf.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/pharmacy/data/pharmacy_remote.dart';
import 'package:zad/features/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

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

/// Answers the medicine list and nothing else — nothing is sent here.
class _Pharmacy implements PharmacyRemote {
  List<Map<String, dynamic>> medicines = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchMedicines({
    required String userId,
  }) async => medicines;

  @override
  Future<List<DateTime>> fetchDoseRecords({
    required String userId,
    required String medicineId,
    required DateTime since,
  }) async => <DateTime>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;

  @override
  Future<DoseReceipt> logDose({
    required String userId,
    required String medicineId,
    DateTime? scheduledAt,
    DateTime? takenAt,
  }) async => const DoseReceipt(ok: true, duplicate: false);

  @override
  Future<RestockReceipt> restock({
    required String userId,
    required String restockId,
    required String medicineId,
    required int quantity,
    String? name,
    String? unit,
    String? category,
  }) async => const RestockReceipt(ok: false, reason: 'not_sent_here');

  @override
  Future<void> remove(String id) async {}

  @override
  Future<Map<String, dynamic>?> snoozeReturning(
    Map<String, dynamic> row,
  ) async => row;
}

class _Accepting implements ShoppingListRemote, InventoryRemote {
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

class _NoTransactions implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

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
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> pharmacyBox;
  late Box<String> shoppingBox;
  late Box<String> outboxBox;
  late _Scanner scanner;
  late _Pharmacy pharmacyRemote;
  late Outbox outbox;
  late PharmacyRepository pharmacy;
  late ShoppingListRepository shopping;
  var ids = 0;
  var run = 0;
  final now = DateTime.parse('2026-09-21T09:00:00Z');

  setUp(() async {
    run++;
    ids = 0;
    dir = await Directory.systemTemp.createTemp('zad_pharmacy_receipt_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    transactions = await Hive.openBox<String>('transactions$run');
    pharmacyBox = await Hive.openBox<String>('pharmacy$run');
    shoppingBox = await Hive.openBox<String>('shopping$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    scanner = _Scanner()
      ..answer = <String, dynamic>{
        'total': 310,
        'category': 'الرعاية الصحية',
        'storeName': 'صيدلية العزبي',
        'receiptType': 'pharmacy',
        'items': <Object?>[
          // Tracked, and the box says what it holds.
          <String, dynamic>{'name': 'كونكور 5 مجم 30 قرص', 'quantity': 2},
          // New, and it says too.
          <String, dynamic>{'name': 'أوجمنتين 1 جم 14 قرص', 'quantity': 1},
          // Tracked, and it does not.
          <String, dynamic>{
            'name': 'فيتامين د3',
            'quantity': 1,
            'unit': 'علبة',
          },
        ],
      };
    // Never sent in these tests: nothing flushes the queue.
    outbox = Outbox(box: outboxBox, send: (_) async {}, clock: () => now);
    pharmacyRemote = _Pharmacy()
      ..medicines = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'concor',
          'user_id': 'user-1',
          'name': 'كونكور 5',
          'unit': 'قرص',
          'remaining_quantity': 3,
        },
        <String, dynamic>{
          'id': 'vitd',
          'user_id': 'user-1',
          'name': 'فيتامين د3',
          'unit': 'قرص',
          'remaining_quantity': 4,
        },
      ];
    pharmacy = PharmacyRepository(
      cache: pharmacyBox,
      remote: pharmacyRemote,
      outbox: () => outbox,
      newId: () => 'ph-${ids++}',
      signedInUserId: () => 'user-1',
    );
    shopping = ShoppingListRepository(
      cache: shoppingBox,
      remote: _Accepting(),
      outbox: () => outbox,
      newId: () => 'shop-${ids++}',
      signedInUserId: () => 'user-1',
    );
    await pharmacy.refresh();
    await shopping.add(itemName: 'كونكور 5');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer container({bool pharmacyBreaks = false}) =>
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
          pharmacyRepositoryProvider.overrideWithValue(
            pharmacyBreaks
                // Reads fine, refuses every write: the cache is there, the
                // account is not.
                ? PharmacyRepository(
                    cache: pharmacyBox,
                    remote: pharmacyRemote,
                    outbox: () => outbox,
                    newId: () => 'ph-${ids++}',
                    signedInUserId: () => null,
                  )
                : pharmacy,
          ),
          shoppingListRepositoryProvider.overrideWithValue(shopping),
        ],
      );

  Future<ScanController> scanned(ProviderContainer c) async {
    final controller = c.read(scanControllerProvider.notifier);
    await controller.scan(ReceiptImageSource.camera);
    return controller;
  }

  Map<String, int?> stock() => <String, int?>{
    for (final m in pharmacy.cached()) m.name: m.remainingQuantity,
  };

  List<Map<String, dynamic>> restocks() => <Map<String, dynamic>>[
    for (final e in outbox.entries())
      if (e.kind == OutboxKind.restockPharmacyItem) e.payload,
  ];

  test('the reading says what each line would do', () async {
    final c = container();
    addTearDown(c.dispose);
    await scanned(c);

    final view = c.read(scanControllerProvider);
    expect(view.offersPharmacy, isTrue);
    expect(view.offersPantry, isFalse);
    expect(
      <Object?>[
        for (final p in view.pharmacy) (p.medicine?.id, p.count, p.unit),
      ],
      <Object?>[
        ('concor', 60, 'قرص'),
        (null, 14, 'قرص'),
        ('vitd', null, 'قرص'),
      ],
    );
  });

  test('saving tops up, starts, ticks off, leaves the uncounted', () async {
    final c = container();
    addTearDown(c.dispose);
    expect(await (await scanned(c)).saveAsTransaction(), isTrue);

    expect(c.read(transactionsRepositoryProvider).allCached(), hasLength(1));
    expect(stock(), <String, int?>{
      'كونكور 5': 63,
      'أوجمنتين 1 جم 14 قرص': 14,
      // Not 5: a box is not one tablet.
      'فيتامين د3': 4,
    });
    expect(shopping.cached().single.isPurchased, isTrue);

    // Through the restock function only; the upsert never carries stock.
    expect(restocks(), hasLength(2));
    expect(
      outbox.entries().where((e) => e.kind == OutboxKind.upsertPharmacyItem),
      isEmpty,
    );

    final result = c.read(scanControllerProvider).lastPharmacyIntake!;
    expect(
      (result.toppedUp, result.added, result.ticked, result.uncounted),
      (1, 1, 1, 1),
    );
  });

  test("the customer's count fills a box the name did not open", () async {
    final c = container();
    addTearDown(c.dispose);
    final controller = await scanned(c);

    controller.setPharmacyCount(2, 30);
    await controller.saveAsTransaction();

    expect(stock()['فيتامين د3'], 34);
    expect(c.read(scanControllerProvider).lastPharmacyIntake!.uncounted, 0);
  });

  test('a corrected count replaces the one read off the name', () async {
    final c = container();
    addTearDown(c.dispose);
    final controller = await scanned(c);

    controller.setPharmacyCount(0, 28);
    await controller.saveAsTransaction();

    expect(stock()['كونكور 5'], 31);
  });

  test('an unticked line stays out of the pharmacy', () async {
    final c = container();
    addTearDown(c.dispose);
    final controller = await scanned(c);

    controller.toggleItem(1);
    await controller.saveAsTransaction();

    expect(stock().containsKey('أوجمنتين 1 جم 14 قرص'), isFalse);
  });

  test('with the switch off, only the money is recorded', () async {
    final c = container();
    addTearDown(c.dispose);
    final controller = await scanned(c);

    controller.setAddToPharmacy(value: false);
    await controller.saveAsTransaction();

    expect(restocks(), isEmpty);
    expect(shopping.cached().single.isPurchased, isFalse);
    expect(c.read(scanControllerProvider).lastPharmacyIntake, isNull);
  });

  test('a grocery receipt never reaches the pharmacy', () async {
    scanner.answer = <String, dynamic>{
      ...scanner.answer,
      'receiptType': 'grocery',
    };
    final c = container();
    addTearDown(c.dispose);
    await scanned(c);

    expect(c.read(scanControllerProvider).offersPharmacy, isFalse);
  });

  test('a pharmacy that fails does not cost the expense', () async {
    final c = container(pharmacyBreaks: true);
    addTearDown(c.dispose);
    final controller = await scanned(c);
    expect(c.read(scanControllerProvider).offersPharmacy, isTrue);

    expect(await controller.saveAsTransaction(), isTrue);
    expect(c.read(transactionsRepositoryProvider).allCached(), hasLength(1));
    expect(c.read(scanControllerProvider).lastPharmacyIntake?.failed, isTrue);
  });
}
