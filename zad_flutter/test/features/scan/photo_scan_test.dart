// Kotlin's other two camera modes: a pantry shelf and a medicine box.
//
// Pinned here: the answers read the way Kotlin reads them, a box's month-only
// expiry is the end of that month, dose times the server would reject never
// reach the form, a shelf photo goes into the pantry through the receipt's own
// intake (matching, the shopping-list loop, readings before and after), and a
// failed write is not offered again — it may have half landed.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/inventory/data/consumption_observations.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/inventory_repository.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/features/scan/application/photo_scan_controller.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';

class _Camera implements ReceiptCamera {
  Uint8List? image = Uint8List.fromList(<int>[1]);

  @override
  Future<Uint8List?> capture(ReceiptImageSource source) async => image;
}

class _Vision implements VisionScanner {
  List<ScannedPantryItem> items = <ScannedPantryItem>[];
  ScannedMedicine? medicineAnswer;
  Exception? failWith;

  @override
  Future<List<ScannedPantryItem>> pantry({
    required String userId,
    required Uint8List image,
  }) async {
    if (failWith case final e?) throw e;
    return items;
  }

  @override
  Future<ScannedMedicine?> medicine({
    required String userId,
    required Uint8List image,
  }) async {
    if (failWith case final e?) throw e;
    return medicineAnswer;
  }
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

ScannedPantryItem _item(String name, [int qty = 1]) =>
    (name: name, quantity: qty, unit: 'قطعة', category: 'البقالة');

void main() {
  group('reading the answers', () {
    test('a nameless line is dropped, the rest default to one قطعة', () {
      final items = pantryItemsFrom(<String, dynamic>{
        'items': <Object?>[
          <String, dynamic>{'name': '  لبن ', 'quantity': 2.4, 'unit': 'لتر'},
          <String, dynamic>{'name': '', 'quantity': 3},
          <String, dynamic>{'name': 'تونة', 'quantity': 0, 'unit': ' '},
          'noise',
        ],
      });
      expect(items, <ScannedPantryItem>[
        (name: 'لبن', quantity: 2, unit: 'لتر', category: null),
        (name: 'تونة', quantity: 1, unit: 'قطعة', category: null),
      ]);
      expect(pantryItemsFrom(<String, dynamic>{}), isEmpty);
    });

    test('a box with no name is no reading', () {
      expect(medicineFrom(<String, dynamic>{'medicine': null}), isNull);
      expect(
        medicineFrom(<String, dynamic>{
          'medicine': <String, dynamic>{'name': ' '},
        }),
        isNull,
      );
    });

    test('a box reads the way Kotlin reads it', () {
      final m = medicineFrom(<String, dynamic>{
        'medicine': <String, dynamic>{
          'name': 'بنادول',
          'active_ingredient': 'Paracetamol',
          'category': 'مسكن',
          'quantity': 24,
          'unit': 'قرص',
          'expiry_date': '2027-05',
          'daily_dose_count': 3,
          'suggested_times': <String>['08:00', '16:00'],
        },
      })!;
      expect(m.name, 'بنادول');
      expect(m.quantity, 24);
      expect(m.expiryDate, DateTime.utc(2027, 5, 31));
      expect(m.dailyDoseCount, 3);
      expect(m.doseTimes, '08:00,16:00');
    });

    test('a month-only expiry is the last day of that month', () {
      expect(packExpiry('2027-02'), DateTime.utc(2027, 2, 28));
      expect(packExpiry('2028-02'), DateTime.utc(2028, 2, 29));
      expect(packExpiry('2027-12'), DateTime.utc(2027, 12, 31));
      expect(packExpiry('2027-06-15'), DateTime.utc(2027, 6, 15));
      expect(packExpiry('2027-13'), isNull);
      expect(packExpiry('2027-02-30'), isNull);
      expect(packExpiry('EXP 05/27'), isNull);
    });

    test('only times the server accepts reach the form, sorted, once', () {
      expect(scannedDoseTimes('20:00, 8:00,24:00,08:00,soon'), <String>[
        '08:00',
        '20:00',
      ]);
      expect(scannedDoseTimes(null), isEmpty);
    });
  });

  group('a photo, read', () {
    late Directory dir;
    late Box<String> inventoryBox;
    late Box<String> shoppingBox;
    late Box<String> outboxBox;
    late Outbox outbox;
    late InventoryRepository inventory;
    late ShoppingListRepository shopping;
    late _Camera camera;
    late _Vision vision;
    var ids = 0;
    var run = 0;
    final now = DateTime.parse('2026-09-25T09:00:00Z');

    setUp(() async {
      run++;
      ids = 0;
      dir = await Directory.systemTemp.createTemp('zad_photo_test');
      Hive.init(dir.path);
      inventoryBox = await Hive.openBox<String>('inventory$run');
      shoppingBox = await Hive.openBox<String>('shopping$run');
      outboxBox = await Hive.openBox<String>('outbox$run');
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
      camera = _Camera();
      vision = _Vision()
        ..items = <ScannedPantryItem>[
          _item('لبن', 2),
          _item('عيش بلدي'),
          _item('شيبسي', 3),
        ];
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
            receiptCameraProvider.overrideWithValue(camera),
            visionScannerProvider.overrideWithValue(vision),
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

    test('ticked items go into the pantry and close the list', () async {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(photoScanControllerProvider.notifier);

      await controller.scan(PhotoKind.pantry, ReceiptImageSource.camera);
      expect(c.read(photoScanControllerProvider).stage, ScanStage.ready);

      controller.toggleItem(2); // the crisps were the neighbour's
      expect(await controller.savePantry(), isTrue);

      final rows = {for (final i in inventory.cached()) i.itemName: i.quantity};
      expect(rows, <String, int>{'اللبن': 3, 'عيش بلدي': 1});
      expect(shopping.cached().single.isPurchased, isTrue);

      final view = c.read(photoScanControllerProvider);
      expect(view.stage, ScanStage.idle);
      final intake = view.lastIntake!;
      expect((intake.added, intake.toppedUp, intake.ticked), (1, 1, 1));

      // The level before the top-up as well as after it.
      expect(
        <num>[
          for (final e in outbox.entries())
            if (e.kind == OutboxKind.recordObservation &&
                e.payload['item'] == 'اللبن')
              e.payload['qty'] as num,
        ],
        <num>[1, 3],
      );
    });

    test('nothing ticked, nothing saved', () async {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(photoScanControllerProvider.notifier);
      await controller.scan(PhotoKind.pantry, ReceiptImageSource.camera);
      for (var i = 0; i < 3; i++) {
        controller.toggleItem(i);
      }
      expect(await controller.savePantry(), isFalse);
      expect(inventory.cached(), hasLength(1));
    });

    test('a photo with no items is unreadable, not an empty save', () async {
      vision.items = <ScannedPantryItem>[];
      final c = container();
      addTearDown(c.dispose);
      await c
          .read(photoScanControllerProvider.notifier)
          .scan(PhotoKind.pantry, ReceiptImageSource.gallery);
      expect(c.read(photoScanControllerProvider).stage, ScanStage.unreadable);
    });

    test('a transport failure is failed, and backing out is nothing', () async {
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(photoScanControllerProvider.notifier);

      vision.failWith = const SocketException('offline');
      await controller.scan(PhotoKind.medicine, ReceiptImageSource.camera);
      expect(c.read(photoScanControllerProvider).stage, ScanStage.failed);

      camera.image = null;
      await controller.scan(PhotoKind.medicine, ReceiptImageSource.camera);
      expect(c.read(photoScanControllerProvider).stage, ScanStage.idle);
    });

    test('a box is read and handed over, not saved', () async {
      vision.medicineAnswer = medicineFrom(<String, dynamic>{
        'medicine': <String, dynamic>{'name': 'كونكور 5'},
      });
      final c = container();
      addTearDown(c.dispose);
      final controller = c.read(photoScanControllerProvider.notifier);

      await controller.scan(PhotoKind.medicine, ReceiptImageSource.camera);
      final view = c.read(photoScanControllerProvider);
      expect(view.stage, ScanStage.ready);
      expect(view.medicine?.name, 'كونكور 5');

      vision.medicineAnswer = null;
      await controller.scan(PhotoKind.medicine, ReceiptImageSource.camera);
      expect(c.read(photoScanControllerProvider).stage, ScanStage.unreadable);
    });

    test('a failed write is reported and not offered again', () async {
      final c = container(pantryBreaks: true);
      addTearDown(c.dispose);
      final controller = c.read(photoScanControllerProvider.notifier);
      await controller.scan(PhotoKind.pantry, ReceiptImageSource.camera);

      expect(await controller.savePantry(), isFalse);
      final view = c.read(photoScanControllerProvider);
      expect(view.lastIntake?.failed, isTrue);
      expect(view.items, isEmpty);
      expect(await controller.savePantry(), isFalse);
    });
  });
}
