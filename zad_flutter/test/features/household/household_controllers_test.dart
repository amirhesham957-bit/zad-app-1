// The screens' state for the pantry and the pharmacy.
//
// The repositories are tested next door. What these pin is the part that only
// exists at this layer: that the pantry puts shortages on the shopping list by
// itself, once, and says so; that the pharmacy answers "what is due today" in
// the account's zone and not the device's; and that taking a dose is on screen
// before it reaches a network.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/inventory_repository.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/data/pharmacy_remote.dart';
import 'package:zad/features/pharmacy/data/pharmacy_repository.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/settings/data/settings_repository.dart';

class _Pantry implements InventoryRemote {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => rows;

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

class _Pharmacy implements PharmacyRemote {
  List<Map<String, dynamic>> medicines = <Map<String, dynamic>>[];
  List<DateTime> records = <DateTime>[];
  int doseCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchMedicines({
    required String userId,
  }) async => medicines;

  @override
  Future<List<DateTime>> fetchDoseRecords({
    required String userId,
    required String medicineId,
    required DateTime since,
  }) async => records;

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
  }) async {
    doseCalls++;
    return const DoseReceipt(ok: true, duplicate: false);
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<Map<String, dynamic>?> snoozeReturning(
    Map<String, dynamic> row,
  ) async => <String, dynamic>{'snooze_until': row['snooze_until']};
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

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late Directory dir;
  late Box<String> documents;
  late Box<String> pantryBox;
  late Box<String> shoppingBox;
  late Box<String> pharmacyBox;
  late Box<String> outboxBox;
  late _Pantry pantryRemote;
  late _Pharmacy pharmacyRemote;

  var now = DateTime.utc(2026, 9, 20, 6);
  var ids = 0;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_household_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    pantryBox = await Hive.openBox<String>('pantry$run');
    shoppingBox = await Hive.openBox<String>('shopping$run');
    pharmacyBox = await Hive.openBox<String>('pharmacy$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    pantryRemote = _Pantry();
    pharmacyRemote = _Pharmacy();
    now = DateTime.utc(2026, 9, 20, 6);
    ids = 0;
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  /// Settings are written before the container is built, so every provider
  /// that reads them sees the same country from its first build.
  Future<void> withCountry(String country) => documents.put(
    'account_settings',
    jsonEncode(<String, dynamic>{'country': country}),
  );

  ProviderContainer containerWith() {
    late PharmacyRepository pharmacy;
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.logPharmacyDose => await pharmacy.sendQueuedDose(entry),
        _ => null,
      },
      clock: () => now,
    );
    pharmacy = PharmacyRepository(
      cache: pharmacyBox,
      remote: pharmacyRemote,
      outbox: () => outbox,
      newId: () => 'm${ids++}',
      signedInUserId: () => 'user-1',
    );

    return ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: documents,
            documents: documents,
            chat: documents,
            inventory: pantryBox,
            shopping: shoppingBox,
            pharmacy: pharmacyBox,
            subscriptions: pharmacyBox,
            device: pharmacyBox,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        outboxProvider.overrideWithValue(outbox),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        inventoryRepositoryProvider.overrideWithValue(
          InventoryRepository(
            cache: pantryBox,
            remote: pantryRemote,
            outbox: () => outbox,
            newId: () => 'p${ids++}',
            signedInUserId: () => 'user-1',
          ),
        ),
        shoppingListRepositoryProvider.overrideWithValue(
          ShoppingListRepository(
            cache: shoppingBox,
            remote: _Shopping(),
            outbox: () => outbox,
            newId: () => 's${ids++}',
            signedInUserId: () => 'user-1',
          ),
        ),
        pharmacyRepositoryProvider.overrideWithValue(pharmacy),
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
      ],
    );
  }

  Map<String, dynamic> pantryRow(String id, String name, int quantity) =>
      <String, dynamic>{
        'id': id,
        'user_id': 'user-1',
        'item_name': name,
        'quantity': quantity,
        'low_stock_threshold': 2,
      };

  group('the account zone', () {
    test('comes from the country, as the cron takes it', () async {
      await withCountry('SA');
      final container = containerWith();
      addTearDown(container.dispose);

      expect(container.read(accountTimeZoneProvider), 'Asia/Riyadh');
    });

    test('falls back to UTC, never to the device', () {
      final container = containerWith();
      addTearDown(container.dispose);

      // The SQL's own fallback for an unknown country.
      expect(container.read(accountTimeZoneProvider), 'UTC');
    });

    test('uses the budget snapshot when there is no country yet', () async {
      await documents.put(
        'budget_state',
        jsonEncode(
          BudgetSnapshot.fromJson(<String, dynamic>{
            'user_id': 'user-1',
            'timezone': 'Africa/Cairo',
            'computed_at': '2026-09-20T00:00:00Z',
          }).toJson(),
        ),
      );
      final container = containerWith();
      addTearDown(container.dispose);

      expect(container.read(accountTimeZoneProvider), 'Africa/Cairo');
    });
  });

  group('the pantry puts what ran out on the list', () {
    test('on refresh, once, and says how many', () async {
      await withCountry('EG');
      pantryRemote.rows = <Map<String, dynamic>>[
        pantryRow('a', 'أرز', 0),
        pantryRow('b', 'لبن', 1),
        pantryRow('c', 'سكر', 9),
      ];
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(pantryControllerProvider.notifier)
          .refresh(force: true);

      final view = container.read(pantryControllerProvider);
      expect(view.shortages.map((s) => s.item.itemName), <String>[
        'أرز',
        'لبن',
      ]);
      expect(view.addedToList, 2);
      expect(
        container.read(shoppingListRepositoryProvider).outstanding(),
        hasLength(2),
      );
    });

    test('a second pass adds nothing and says nothing', () async {
      await withCountry('EG');
      pantryRemote.rows = <Map<String, dynamic>>[pantryRow('a', 'أرز', 0)];
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(pantryControllerProvider.notifier);

      await controller.refresh(force: true);
      await controller.refresh(force: true);

      // Silence the second time. A banner that repeated "added 1" on every
      // refresh would be announcing work that was not done.
      expect(container.read(pantryControllerProvider).addedToList, 0);
      expect(
        container.read(shoppingListRepositoryProvider).outstanding(),
        hasLength(1),
      );
    });

    test('using the last one puts it on the list straight away', () async {
      await withCountry('EG');
      pantryRemote.rows = <Map<String, dynamic>>[pantryRow('a', 'لبن', 3)];
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(pantryControllerProvider.notifier);
      await controller.refresh(force: true);
      expect(
        container.read(shoppingListRepositoryProvider).outstanding(),
        isEmpty,
      );

      await controller.adjust('a', -2);

      expect(
        container
            .read(shoppingListRepositoryProvider)
            .outstanding()
            .single
            .itemName,
        'لبن',
      );
    });
  });

  group('the pharmacy answers in the account zone', () {
    Map<String, dynamic> medicineRow() => <String, dynamic>{
      'id': 'med-1',
      'user_id': 'user-1',
      'name': 'كونكور',
      'dose_times': '08:00,20:00',
      'remaining_quantity': 30,
    };

    test("today's eight o'clock is the market's eight o'clock", () async {
      await withCountry('SA');
      pharmacyRemote.medicines = <Map<String, dynamic>>[medicineRow()];
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(pharmacyControllerProvider.notifier).refresh();

      // 08:00 in Riyadh is 05:00Z. Read in a device zone this would be some
      // other instant, and the screen would disagree with the reminder.
      expect(
        container
            .read(pharmacyControllerProvider)
            .today
            .map((s) => s.scheduledAt),
        contains(DateTime.utc(2026, 9, 20, 5)),
      );
    });

    test("yesterday's doses are not today's tasks", () async {
      // Yesterday is fetched because the cron looks at it, but yesterday
      // morning's tablet is history. Showing it would put a dose on today's
      // list that nobody can take any more.
      await withCountry('SA');
      pharmacyRemote.medicines = <Map<String, dynamic>>[medicineRow()];
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(pharmacyControllerProvider.notifier).refresh();

      expect(
        container
            .read(pharmacyControllerProvider)
            .today
            .any((s) => s.scheduledAt == DateTime.utc(2026, 9, 19, 5)),
        isFalse,
      );
    });

    test('taking a dose is on screen before the network', () async {
      await withCountry('SA');
      pharmacyRemote.medicines = <Map<String, dynamic>>[medicineRow()];
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(pharmacyControllerProvider.notifier);
      await controller.refresh();

      final due = container
          .read(pharmacyControllerProvider)
          .today
          .firstWhere((s) => s.scheduledAt == DateTime.utc(2026, 9, 20, 5));
      await controller.take(due);

      final after = container
          .read(pharmacyControllerProvider)
          .today
          .firstWhere((s) => s.scheduledAt == due.scheduledAt);
      expect(after.stateAt(now), DoseState.taken);
      // Queued, not sent: the RPC has not been called.
      expect(pharmacyRemote.doseCalls, 0);
      expect(
        outboxBox.values.where((v) => v.contains('log_pharmacy_dose')),
        hasLength(1),
      );
    });

    test('putting one off is remembered for that slot', () async {
      await withCountry('SA');
      pharmacyRemote.medicines = <Map<String, dynamic>>[medicineRow()];
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(pharmacyControllerProvider.notifier);
      await controller.refresh();

      final due = container.read(pharmacyControllerProvider).today.first;
      await controller.snooze(due);

      expect(controller.isSnoozed(due), isTrue);
    });
  });
}
