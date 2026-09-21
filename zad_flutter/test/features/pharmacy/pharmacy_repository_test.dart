// Recording a dose, offline, without taking a second tablet off the count.
//
// The dose path is the only write in this app that goes through an RPC rather
// than an upsert, because `zad_log_pharmacy_dose_atomic` does three things in
// one transaction: it records the dose, it decrements `remaining_quantity`
// carrying the fraction, and it puts the medicine on the shopping list when
// that drops under a day's worth. The client queues a call to it and writes
// none of those columns itself.
//
// Everything below is about the two ways that can go wrong: recording twice,
// and recording nothing while saying otherwise.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/pharmacy/data/pharmacy_remote.dart';
import 'package:zad/features/pharmacy/data/pharmacy_repository.dart';

class _FakeRemote implements PharmacyRemote {
  List<Map<String, dynamic>> medicines = <Map<String, dynamic>>[];
  List<DateTime> records = <DateTime>[];
  final List<Map<String, Object?>> logged = <Map<String, Object?>>[];
  final List<String> removed = <String>[];

  DoseReceipt receipt = const DoseReceipt(
    ok: true,
    duplicate: false,
    remainingQuantity: 29,
  );
  Exception? failWith;

  @override
  Future<List<Map<String, dynamic>>> fetchMedicines({
    required String userId,
  }) async {
    if (failWith case final e?) throw e;
    return medicines;
  }

  @override
  Future<List<DateTime>> fetchDoseRecords({
    required String userId,
    required String medicineId,
    required DateTime since,
  }) async {
    if (failWith case final e?) throw e;
    return records;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final e?) throw e;
    return row;
  }

  @override
  Future<DoseReceipt> logDose({
    required String userId,
    required String medicineId,
    DateTime? scheduledAt,
    DateTime? takenAt,
  }) async {
    if (failWith case final e?) throw e;
    logged.add(<String, Object?>{
      'item': medicineId,
      'slot': scheduledAt,
      'taken': takenAt,
    });
    return receipt;
  }

  /// Stock by medicine id, as `zad_pharmacy_restock` keeps it.
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};

  /// Restock ids already applied — the function's `zad_pharmacy_restocks`.
  final Map<String, String> restocks = <String, String>{};
  int restockCalls = 0;

  /// Overrides the answer, to stage a refusal.
  RestockReceipt? restockAnswer;

  @override
  Future<RestockReceipt> restock({
    required String userId,
    required String restockId,
    required String medicineId,
    required int quantity,
    String? name,
    String? unit,
    String? category,
  }) async {
    if (failWith case final e?) throw e;
    restockCalls++;
    if (restockAnswer case final answer?) return answer;

    if (restocks[restockId] case final prior?) {
      return RestockReceipt(ok: true, duplicate: true, item: rows[prior]);
    }
    var target = rows[medicineId];
    var created = false;
    if (target == null && name != null) {
      // The per-owner name index: a clash goes to the row that has the name.
      target = rows.values
          .where((r) => (r['name'] as String).trim() == name.trim())
          .firstOrNull;
      if (target == null) {
        created = true;
        target = rows[medicineId] = <String, dynamic>{
          'id': medicineId,
          'user_id': userId,
          'name': name,
          'unit': unit ?? 'قرص',
          'category': category ?? 'عام',
          'remaining_quantity': 0,
        };
      }
    }
    if (target == null) {
      return const RestockReceipt(ok: false, reason: 'not_found');
    }
    restocks[restockId] = target['id'] as String;
    target['remaining_quantity'] =
        (target['remaining_quantity'] as int) + quantity;
    return RestockReceipt(
      ok: true,
      created: created,
      item: <String, dynamic>{...target},
    );
  }

  @override
  Future<void> remove(String id) async {
    if (failWith case final e?) throw e;
    removed.add(id);
  }

  /// `zad_dose_snoozes`, keyed as the table is.
  final Map<String, Map<String, dynamic>> snoozes =
      <String, Map<String, dynamic>>{};

  /// Overrides the read-back, to stage a snooze that did not land as sent.
  Map<String, dynamic>? Function(Map<String, dynamic> sent)? snoozeReadBack;

  @override
  Future<Map<String, dynamic>?> snoozeReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final e?) throw e;
    if (snoozeReadBack case final override?) return override(row);
    final key = '${row['user_id']}|${row['item_id']}|${row['scheduled_at']}';
    snoozes[key] = <String, dynamic>{...row};
    return <String, dynamic>{'snooze_until': row['snooze_until']};
  }
}

void main() {
  // Slot arithmetic runs through the zone database, and asking for a location
  // before it is loaded throws rather than falling back to anything.
  setUpAll(tz_data.initializeTimeZones);

  late Directory dir;
  late Box<String> cache;
  late Box<String> outboxBox;
  late _FakeRemote remote;
  late Outbox outbox;
  late PharmacyRepository pharmacy;

  final now = DateTime.utc(2026, 9, 20, 5, 10);
  final slot = DateTime.utc(2026, 9, 20, 5);
  var ids = 0;
  var run = 0;

  setUp(() async {
    run++;
    dir = await Directory.systemTemp.createTemp('zad_pharmacy_test');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('pharmacy$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    remote = _FakeRemote();
    ids = 0;

    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.upsertPharmacyItem => await pharmacy.sendQueued(entry),
        OutboxKind.deletePharmacyItem => await pharmacy.sendQueuedDelete(entry),
        OutboxKind.logPharmacyDose => await pharmacy.sendQueuedDose(entry),
        OutboxKind.upsertDoseSnooze => await pharmacy.sendQueuedSnooze(entry),
        OutboxKind.restockPharmacyItem =>
          await pharmacy.sendQueuedRestock(entry),
        _ => throw StateError('no sender for "${entry.kind}"'),
      },
      clock: () => now,
    );
    pharmacy = PharmacyRepository(
      cache: cache,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'm${ids++}',
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  List<OutboxEntry> queued(String kind) =>
      outbox.entries().where((e) => e.kind == kind).toList();

  Map<String, dynamic> serverMedicine({
    String id = 'srv-1',
    int? remaining = 30,
  }) => <String, dynamic>{
    'id': id,
    'user_id': 'user-1',
    'name': 'كونكور',
    'dose_times': '08:00,20:00',
    'daily_dose_count': 2,
    'units_per_dose': 1,
    'remaining_quantity': remaining,
    'unit': 'قرص',
  };

  group('recording a dose', () {
    test('is queued, not called, so it works with no signal', () async {
      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);

      expect(remote.logged, isEmpty);
      expect(queued(OutboxKind.logPharmacyDose), hasLength(1));
    });

    test('is keyed on the slot, exactly as the RPC conflicts on it', () async {
      // Two taps on the same reminder are one dose. The entry id carries
      // `(item, scheduled_at)` so a second enqueue replaces the first rather
      // than queueing a second call.
      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);

      expect(queued(OutboxKind.logPharmacyDose), hasLength(1));
    });

    test('a different slot is a different dose', () async {
      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      await pharmacy.logDose(
        'srv-1',
        scheduledAt: slot.add(const Duration(hours: 12)),
        takenAt: now,
      );

      expect(queued(OutboxKind.logPharmacyDose), hasLength(2));
    });

    test('an ad-hoc dose carries no slot, and the server buckets it', () async {
      await pharmacy.logDose('srv-1', takenAt: now);

      final payload = queued(OutboxKind.logPharmacyDose).single.payload;
      expect(payload['scheduled_at'], isNull);
      expect(payload['taken_at'], now.toIso8601String());
    });

    test('sending it reaches the RPC with the slot intact', () async {
      remote.medicines = <Map<String, dynamic>>[serverMedicine()];
      await pharmacy.refresh();

      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      await outbox.flush();

      expect(remote.logged.single['item'], 'srv-1');
      expect(remote.logged.single['slot'], slot);
      expect(queued(OutboxKind.logPharmacyDose), isEmpty);
    });
  });

  group('what the RPC says about the count', () {
    test('the remaining figure lands on the cached medicine', () async {
      // So the screen that just recorded a dose shows what is left, rather
      // than the figure from before it.
      remote.medicines = <Map<String, dynamic>>[serverMedicine()];
      await pharmacy.refresh();

      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      await outbox.flush();

      expect(pharmacy.cached().single.remainingQuantity, 29);
    });

    test('a duplicate is a success, not a failure', () async {
      // The insert is `on conflict do nothing`, which is what makes a replay
      // after an ambiguous network failure safe. Treating it as an error
      // would dead-letter a dose that is recorded.
      remote
        ..medicines = <Map<String, dynamic>>[serverMedicine()]
        ..receipt = const DoseReceipt(
          ok: true,
          duplicate: true,
          remainingQuantity: 30,
        );
      await pharmacy.refresh();

      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      final report = await outbox.flush();

      expect(report.sent, 1);
      expect(pharmacy.cached().single.remainingQuantity, 30);
    });

    test('a refusal is surfaced, never swallowed', () async {
      // A dose that silently failed to record is the one outcome this path
      // must not produce.
      remote.receipt = const DoseReceipt(
        ok: false,
        duplicate: false,
        reason: 'not_found',
      );

      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      final report = await outbox.flush();

      expect(report.sent, 0);
      expect(queued(OutboxKind.logPharmacyDose), hasLength(1));
    });

    test('no signal leaves the dose queued for later', () async {
      remote.failWith = const SocketException('offline');

      await pharmacy.logDose('srv-1', scheduledAt: slot, takenAt: now);
      await outbox.flush();

      expect(queued(OutboxKind.logPharmacyDose), hasLength(1));
    });
  });

  group('restocking from a purchase', () {
    Future<void> tracked({int remaining = 3}) async {
      remote.medicines = <Map<String, dynamic>>[
        serverMedicine(remaining: remaining),
      ];
      remote.rows['srv-1'] = serverMedicine(remaining: remaining);
      await pharmacy.refresh();
    }

    test('is queued, and the sum is on screen at once', () async {
      await tracked();

      await pharmacy.restock('srv-1', 30);

      expect(remote.restockCalls, 0);
      expect(queued(OutboxKind.restockPharmacyItem), hasLength(1));
      final shown = pharmacy.cached().single;
      expect((shown.remainingQuantity, shown.isPending), (33, true));
    });

    test('never writes remaining_quantity through the upsert', () async {
      // The dose RPC moves that column. An upsert of 33 sent after a dose
      // took one would put the tablet back.
      await tracked();

      await pharmacy.restock('srv-1', 30);

      expect(queued(OutboxKind.upsertPharmacyItem), isEmpty);
    });

    test('two purchases of one medicine are two restocks', () async {
      // Keyed on the purchase, not the medicine: one must not replace the
      // other the way a second edit replaces the first.
      await tracked();

      await pharmacy.restock('srv-1', 30);
      await pharmacy.restock('srv-1', 30);

      expect(queued(OutboxKind.restockPharmacyItem), hasLength(2));
      expect(pharmacy.cached().single.remainingQuantity, 63);
    });

    test("sending it settles on the server's figure", () async {
      await tracked();
      // A dose taken through the bot while the restock waited.
      remote.rows['srv-1']!['remaining_quantity'] = 2;

      await pharmacy.restock('srv-1', 30);
      await outbox.flush();

      final settled = pharmacy.cached().single;
      expect((settled.remainingQuantity, settled.isPending), (32, false));
      expect(queued(OutboxKind.restockPharmacyItem), isEmpty);
    });

    test('a replay after an ambiguous failure adds nothing', () async {
      await tracked();
      await pharmacy.restock('srv-1', 30);
      final entry = queued(OutboxKind.restockPharmacyItem).single;

      await pharmacy.sendQueuedRestock(entry);
      await pharmacy.sendQueuedRestock(entry);

      expect(remote.rows['srv-1']!['remaining_quantity'], 33);
      expect(pharmacy.cached().single.remainingQuantity, 33);
    });

    test('a refusal is surfaced, never swallowed', () async {
      await tracked();
      remote.restockAnswer = const RestockReceipt(
        ok: false,
        reason: 'not_found',
      );

      await pharmacy.restock('srv-1', 30);
      final report = await outbox.flush();

      expect(report.sent, 0);
      expect(queued(OutboxKind.restockPharmacyItem), hasLength(1));
    });

    test('nothing, or less than one, is not a purchase', () async {
      await tracked();

      await pharmacy.restock('srv-1', 0);

      expect(queued(OutboxKind.restockPharmacyItem), isEmpty);
    });
  });

  group('a medicine bought for the first time', () {
    test('lands with its count, not the column default', () async {
      final started = await pharmacy.restockNew(
        name: 'أوجمنتين 1جم',
        count: 14,
        unit: 'قرص',
        category: 'مضاد حيوي',
      );
      expect(pharmacy.cached().single.remainingQuantity, 14);

      final payload = queued(OutboxKind.restockPharmacyItem).single.payload;
      expect(payload['item_id'], started.id);
      expect(payload['name'], 'أوجمنتين 1جم');
      expect(queued(OutboxKind.upsertPharmacyItem), isEmpty);

      await outbox.flush();

      final settled = pharmacy.cached().single;
      expect(remote.rows[started.id]!['remaining_quantity'], 14);
      expect((settled.remainingQuantity, settled.isPending), (14, false));
    });

    test('survives a refresh before it is sent', () async {
      await pharmacy.restockNew(name: 'بانادول', count: 24, unit: 'قرص');
      remote.medicines = <Map<String, dynamic>>[serverMedicine()];

      await pharmacy.refresh();

      expect(
        pharmacy.cached().map((m) => m.name),
        containsAll(<String>['بانادول', 'كونكور']),
      );
    });

    test('a name the server already has goes to that medicine', () async {
      // Added by voice since the last refresh: the server restocks its row,
      // and the phone swaps its own copy for it rather than showing two.
      remote.rows['srv-1'] = serverMedicine(remaining: 5);

      await pharmacy.restockNew(name: 'كونكور', count: 30, unit: 'قرص');
      await outbox.flush();

      final only = pharmacy.cached().single;
      expect((only.id, only.remainingQuantity), ('srv-1', 35));
    });
  });

  group('putting a dose off', () {
    test('quietens this slot and no other', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect(pharmacy.isSnoozed('srv-1', slot, now), isTrue);
      expect(
        pharmacy.isSnoozed('srv-1', slot.add(const Duration(hours: 12)), now),
        isFalse,
      );
      expect(pharmacy.isSnoozed('other', slot, now), isFalse);
    });

    test('wears off', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect(
        pharmacy.isSnoozed(
          'srv-1',
          slot,
          now.add(PharmacyRepository.snoozeFor).add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test("lasts as long as the bot's snooze", () {
      // DOSE_SNOOZE_MINUTES in zad-telegram-bot/telegram.ts. Both surfaces
      // now write the same row, so one dose must not get two lengths.
      expect(PharmacyRepository.snoozeFor, const Duration(minutes: 15));
    });

    test("is queued for the server under the table's own key", () async {
      // Owner decision 2026-09-21, migration 20260921120000: an app snooze
      // must quieten the server's reminders and the bot too, and they only
      // read `zad_dose_snoozes`.
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      final entry = queued(OutboxKind.upsertDoseSnooze).single;
      expect(entry.id, DoseSnooze.keyFor('srv-1', slot));
      expect(entry.payload, <String, dynamic>{
        'user_id': 'user-1',
        'item_id': 'srv-1',
        'scheduled_at': slot.toIso8601String(),
        'snooze_until': now.add(PharmacyRepository.snoozeFor).toIso8601String(),
      });
    });

    test('putting it off again replaces the queued write', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);
      final later = now.add(const Duration(minutes: 10));
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: later);

      final entry = queued(OutboxKind.upsertDoseSnooze).single;
      expect(
        entry.payload['snooze_until'],
        later.add(PharmacyRepository.snoozeFor).toIso8601String(),
      );
    });

    test('is sent, read back, and settled', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);
      final report = await outbox.flush();

      expect(report.sent, 1);
      expect(remote.snoozes, hasLength(1));
      expect(queued(OutboxKind.upsertDoseSnooze), isEmpty);
    });

    test('a later snooze_until on the server still counts as sent', () async {
      // The bot may have put the same dose off again in the meantime.
      remote.snoozeReadBack = (sent) => <String, dynamic>{
        'snooze_until': '2026-09-20T09:00:00+00:00',
      };
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect((await outbox.flush()).sent, 1);
    });

    test('stays queued when no row reads back', () async {
      remote.snoozeReadBack = (_) => null;
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect((await outbox.flush()).sent, 0);
      expect(queued(OutboxKind.upsertDoseSnooze), hasLength(1));
    });

    test('stays queued when the snooze ends earlier than asked', () async {
      // Then the server reminds about a dose the screen says is quiet.
      remote.snoozeReadBack = (sent) => <String, dynamic>{
        'snooze_until': slot.toIso8601String(),
      };
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect((await outbox.flush()).sent, 0);
      expect(queued(OutboxKind.upsertDoseSnooze), hasLength(1));
    });

    test('refuses to snooze with nobody signed in', () async {
      final signedOut = PharmacyRepository(
        cache: cache,
        remote: remote,
        outbox: () => outbox,
        newId: () => 'x',
        signedInUserId: () => null,
      );
      await expectLater(
        signedOut.snooze('srv-1', scheduledAt: slot, now: now),
        throwsStateError,
      );
      expect(signedOut.isSnoozed('srv-1', slot, now), isFalse);
    });

    test('expired snoozes are cleared out', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);
      await pharmacy.pruneSnoozes(now.add(const Duration(hours: 2)));

      expect(pharmacy.isSnoozed('srv-1', slot, now), isFalse);
    });

    test('pruning leaves a snooze that is still in force', () async {
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);
      await pharmacy.pruneSnoozes(now.add(const Duration(minutes: 5)));

      expect(
        pharmacy.isSnoozed('srv-1', slot, now.add(const Duration(minutes: 5))),
        isTrue,
      );
    });
  });

  group('the medicine list', () {
    test('keeps a queued row through a refresh', () async {
      await pharmacy.add(name: 'بنادول', doseTimes: '08:00');
      remote.medicines = <Map<String, dynamic>>[serverMedicine()];

      await pharmacy.refresh();

      expect(
        pharmacy.cached().map((m) => m.name),
        containsAll(<String>['بنادول', 'كونكور']),
      );
    });

    test('never sends the columns the RPC owns', () async {
      await pharmacy.add(name: 'بنادول', remainingQuantity: 10);

      final payload = queued(OutboxKind.upsertPharmacyItem).single.payload;
      // `remaining_quantity` and `dose_carry` move inside the dose
      // transaction; writing them here would race it for the same number.
      expect(payload.containsKey('remaining_quantity'), isFalse);
      expect(payload.containsKey('dose_carry'), isFalse);
      expect(payload.containsKey('has_invalid_dose_time'), isFalse);
    });

    test('a snooze is not mistaken for a medicine', () async {
      // Both live in one box, under different key prefixes.
      await pharmacy.add(name: 'بنادول');
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect(pharmacy.cached(), hasLength(1));
    });

    test('removing one queues the delete', () async {
      remote.medicines = <Map<String, dynamic>>[serverMedicine()];
      await pharmacy.refresh();

      await pharmacy.remove('srv-1');
      await outbox.flush();

      expect(pharmacy.cached(), isEmpty);
      expect(remote.removed, <String>['srv-1']);
    });

    test('refuses to write with nobody signed in', () async {
      final orphan = PharmacyRepository(
        cache: cache,
        remote: remote,
        outbox: () => outbox,
        newId: () => 'x',
        signedInUserId: () => null,
      );

      await expectLater(orphan.add(name: 'بنادول'), throwsStateError);
    });
  });

  group('slots with records applied', () {
    test('a recorded dose comes back marked', () async {
      remote
        ..medicines = <Map<String, dynamic>>[serverMedicine()]
        ..records = <DateTime>[slot.add(const Duration(minutes: 20))];
      await pharmacy.refresh();

      final slots = await pharmacy.slotsFor(
        pharmacy.cached().single,
        now: now,
        timeZone: 'Asia/Riyadh',
      );

      expect(slots.where((s) => s.isTaken), hasLength(1));
    });

    test(
      'a medicine with nothing left has no slots and asks for nothing',
      () async {
        remote.medicines = <Map<String, dynamic>>[serverMedicine(remaining: 0)];
        await pharmacy.refresh();

        final slots = await pharmacy.slotsFor(
          pharmacy.cached().single,
          now: now,
          timeZone: 'Asia/Riyadh',
        );

        expect(slots, isEmpty);
      },
    );
  });
}
