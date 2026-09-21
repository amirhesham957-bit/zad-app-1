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

  @override
  Future<void> remove(String id) async {
    if (failWith case final e?) throw e;
    removed.add(id);
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

    test('never reaches the server', () async {
      // `zad_dose_snoozes` has a select policy and no insert policy — the
      // rows come from the Telegram bot on the service-role key. Queueing one
      // would dead-letter on an RLS refusal, and claiming the server had been
      // told would be worse than the gap itself.
      await pharmacy.snooze('srv-1', scheduledAt: slot, now: now);

      expect(outbox.entries(), isEmpty);
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
