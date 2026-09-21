/// The pharmacy, offline first.
///
/// Recording a dose is the one write in this app that is **not** a plain
/// upsert. `zad_log_pharmacy_dose_atomic` inserts the dose, decrements
/// `remaining_quantity` carrying the fraction in `dose_carry`, and adds the
/// medicine to the shopping list when it drops under a day's worth — one
/// transaction, three effects. The client queues a call to it and never writes
/// those columns itself, because doing so would race the RPC for the same
/// numbers.
///
/// It is safe to retry by construction: the insert is `on conflict (user_id,
/// item_id, scheduled_at) do nothing`, so a replay after an ambiguous failure
/// answers `duplicate: true` rather than taking a second tablet off the count.
/// The queued entry's id carries the same three parts for the same reason.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/pharmacy/data/pharmacy_remote.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// A dose the customer put off, remembered on this device.
class DoseSnooze {
  /// Creates a snooze.
  const new({
    required this.medicineId,
    required this.scheduledAt,
    required this.until,
  });

  /// Reads one back out of the cache.
  factory fromJson(Map<String, dynamic> json) => DoseSnooze(
    medicineId: json['medicine_id'] as String,
    scheduledAt: DateTime.parse(json['scheduled_at'] as String).toUtc(),
    until: DateTime.parse(json['until'] as String).toUtc(),
  );

  /// Which medicine.
  final String medicineId;

  /// Which slot.
  final DateTime scheduledAt;

  /// When to ask again.
  final DateTime until;

  /// Whether it is still in force at [now].
  bool coversAt(DateTime now) => now.toUtc().isBefore(until);

  /// The key a slot is remembered under.
  static String keyFor(String medicineId, DateTime scheduledAt) =>
      'snooze:$medicineId:${scheduledAt.toUtc().toIso8601String()}';

  /// Writes it into the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'medicine_id': medicineId,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'until': until.toUtc().toIso8601String(),
  };
}

/// Holds the pharmacy.
class PharmacyRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required PharmacyRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _cache = cache,
       _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final Box<String> _cache;
  final PharmacyRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// How long a put-off dose stays quiet.
  ///
  /// The Telegram bot's figure — `DOSE_SNOOZE_MINUTES` in
  /// `zad-telegram-bot/telegram.ts` — so a dose deferred on one surface reads
  /// the same on the other. It said so here while being 30, twice the bot's
  /// 15; harmless while the app's snooze stayed on the device, not once both
  /// write the same row.
  static const Duration snoozeFor = Duration(minutes: 15);

  /// How far back dose records are read.
  ///
  /// Two days covers the slot window — today and yesterday — plus the
  /// three-hour grace either side of the earliest of them.
  static const Duration recordWindow = Duration(days: 2);

  static const String _medicinePrefix = 'med:';

  /// Every medicine on the device, by name.
  List<Medicine> cached() {
    final medicines = <Medicine>[];
    for (final key in _cache.keys) {
      if (key is! String || !key.startsWith(_medicinePrefix)) continue;
      final medicine = _read(_cache.get(key) ?? '');
      if (medicine != null) medicines.add(medicine);
    }
    return medicines..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Asks the server and replaces what it answered for, keeping queued rows.
  Future<List<Medicine>> refresh() async {
    final rows = await _remote.fetchMedicines(userId: _requireUserId());
    final server = rows
        .map(Medicine.fromJson)
        .map((m) => m.markPending(pending: false))
        .toList();
    final serverIds = server.map((m) => m.id).toSet();

    final stale = cached()
        .where((m) => !m.isPending && !serverIds.contains(m.id))
        .map((m) => '$_medicinePrefix${m.id}');
    await _cache.deleteAll(stale);

    await _cache.putAll(<String, String>{
      for (final medicine in server)
        '$_medicinePrefix${medicine.id}': jsonEncode(medicine.toCacheJson()),
    });

    return cached();
  }

  /// The slots for [medicine] around [now], with recorded doses applied.
  ///
  /// [timeZone] is the **account's** market zone. Passing the device's is the
  /// bug `dose_slot.dart` exists to prevent, and this signature is where it
  /// would be introduced, so it has no default.
  Future<List<DoseSlot>> slotsFor(
    Medicine medicine, {
    required DateTime now,
    required String timeZone,
  }) async {
    final slots = doseSlotsFor(medicine, now: now, timeZone: timeZone);
    if (slots.isEmpty) return slots;

    final records = await _remote.fetchDoseRecords(
      userId: _requireUserId(),
      medicineId: medicine.id,
      since: now.toUtc().subtract(recordWindow),
    );

    return applyRecords(slots, records);
  }

  /// Adds a medicine.
  Future<Medicine> add({
    required String name,
    String? dosage,
    String? category,
    String? unit,
    String? doseTimes,
    int? dailyDoseCount,
    double unitsPerDose = 1,
    int? remainingQuantity,
    DateTime? expiryDate,
  }) async {
    final medicine = Medicine(
      id: _newId(),
      userId: _requireUserId(),
      name: name.trim(),
      dosage: dosage,
      category: category,
      unit: unit,
      doseTimesRaw: doseTimes,
      dailyDoseCount: dailyDoseCount,
      unitsPerDose: unitsPerDose,
      remainingQuantity: remainingQuantity,
      expiryDate: expiryDate,
      isPending: true,
    );
    await _save(medicine);
    return medicine;
  }

  /// Writes a changed medicine.
  Future<Medicine> update(Medicine medicine) async {
    final pending = medicine.markPending(pending: true);
    await _save(pending);
    return pending;
  }

  /// Adds [count] to a tracked medicine's stock — a purchase.
  ///
  /// Queued for `zad_pharmacy_restock`, never written as a new
  /// `remaining_quantity`: the dose RPC moves that column, and a count
  /// computed here would overwrite any dose it took in the meantime. The
  /// screen shows the sum at once; the server's figure replaces it when the
  /// restock is sent.
  Future<void> restock(String medicineId, int count) async {
    if (count < 1) return;
    await _enqueueRestock(medicineId: medicineId, count: count);

    final key = '$_medicinePrefix$medicineId';
    final current = _read(_cache.get(key) ?? '');
    if (current == null) return;
    await _cache.put(
      key,
      jsonEncode(
        current
            .copyWith(
              remainingQuantity: (current.remainingQuantity ?? 0) + count,
              isPending: true,
            )
            .toCacheJson(),
      ),
    );
  }

  /// Starts tracking a medicine with [count] [unit]s in stock.
  ///
  /// Through the restock function rather than [add]: the plain upsert never
  /// carries `remaining_quantity`, and the column defaults to 1, so a new
  /// medicine sent that way would arrive as a single tablet.
  Future<Medicine> restockNew({
    required String name,
    required int count,
    required String unit,
    String? category,
  }) async {
    final medicine = Medicine(
      id: _newId(),
      userId: _requireUserId(),
      name: name.trim(),
      unit: unit,
      category: category,
      remainingQuantity: count,
      // The column's default. A medicine bought is not yet a course.
      isRecurring: false,
      isPending: true,
    );
    await _enqueueRestock(
      medicineId: medicine.id,
      count: count,
      name: medicine.name,
      unit: unit,
      category: category,
    );
    await _cache.put(
      '$_medicinePrefix${medicine.id}',
      jsonEncode(medicine.toCacheJson()),
    );
    return medicine;
  }

  /// Sends one queued restock, and keeps the row the server answers with.
  ///
  /// That row can be a different one from the row asked for: a medicine
  /// started here under a name the server already has — added by voice or on
  /// another phone since the last refresh — is restocked there instead, and
  /// the local copy is dropped for it.
  Future<void> sendQueuedRestock(OutboxEntry entry) async {
    final payload = entry.payload;
    final asked = payload['item_id'] as String;
    final receipt = await _remote.restock(
      userId: payload['user_id'] as String,
      restockId: payload['restock_id'] as String,
      medicineId: asked,
      quantity: payload['quantity'] as int,
      name: payload['name'] as String?,
      unit: payload['unit'] as String?,
      category: payload['category'] as String?,
    );

    // Thrown, like a refused dose, so the outbox keeps a dead letter: stock
    // the customer was told went in must not vanish quietly.
    if (!receipt.ok) {
      throw StateError(
        'zad_pharmacy_restock refused: ${receipt.reason ?? 'unknown'}',
      );
    }

    // A replay of a restock whose medicine has since been deleted.
    final item = receipt.item;
    if (item == null) return;

    final confirmed = Medicine.fromJson(item).markPending(pending: false);
    if (confirmed.id != asked) await _cache.delete('$_medicinePrefix$asked');
    await _cache.put(
      '$_medicinePrefix${confirmed.id}',
      jsonEncode(confirmed.toCacheJson()),
    );
  }

  Future<void> _enqueueRestock({
    required String medicineId,
    required int count,
    String? name,
    String? unit,
    String? category,
  }) async {
    final restockId = _newId();
    await _outbox().enqueue(
      // The function's own key. Not the medicine's: two purchases of the same
      // medicine are two restocks, and one must not replace the other.
      id: 'restock:$restockId',
      kind: OutboxKind.restockPharmacyItem,
      payload: <String, dynamic>{
        'user_id': _requireUserId(),
        'restock_id': restockId,
        'item_id': medicineId,
        'quantity': count,
        'name': ?name,
        'unit': ?unit,
        'category': ?category,
      },
    );
  }

  /// Records a dose: queued, and safe to replay.
  ///
  /// [scheduledAt] is the slot being answered. Leaving it null is how an
  /// ad-hoc "I took it just now" is recorded — the RPC then buckets it to the
  /// nearest five minutes, which makes a network retry idempotent without
  /// blocking a genuine later dose.
  Future<void> logDose(
    String medicineId, {
    required DateTime takenAt,
    DateTime? scheduledAt,
  }) async {
    final slot = scheduledAt?.toUtc();

    await _outbox().enqueue(
      // The RPC's own conflict key, so a queued replay and a server replay
      // collide on the same thing.
      id: 'dose:$medicineId:${slot?.toIso8601String() ?? 'adhoc'}',
      kind: OutboxKind.logPharmacyDose,
      payload: <String, dynamic>{
        'user_id': _requireUserId(),
        'item_id': medicineId,
        'scheduled_at': slot?.toIso8601String(),
        'taken_at': takenAt.toUtc().toIso8601String(),
      },
    );
  }

  /// Puts a dose off for [snoozeFor]: on this device at once, and on the
  /// server through the outbox.
  ///
  /// The server's copy is what makes it a real snooze.
  /// `zad_enqueue_missed_doses` drops a dose from every reminder window while
  /// a row in `zad_dose_snoozes` covers it, and sends one reminder when it
  /// ends — so without the row, the nudge and the "you missed it" message
  /// still go out through the bot for a dose the customer just deferred.
  /// Clients could not write that table until
  /// `20260921120000_app_snoozes_its_own_doses`.
  Future<DoseSnooze> snooze(
    String medicineId, {
    required DateTime scheduledAt,
    required DateTime now,
    Duration? forDuration,
  }) async {
    final snooze = DoseSnooze(
      medicineId: medicineId,
      scheduledAt: scheduledAt.toUtc(),
      until: now.toUtc().add(forDuration ?? snoozeFor),
    );
    final key = DoseSnooze.keyFor(medicineId, scheduledAt);

    await _outbox().enqueue(
      id: key,
      kind: OutboxKind.upsertDoseSnooze,
      payload: <String, dynamic>{
        'user_id': _requireUserId(),
        'item_id': medicineId,
        'scheduled_at': snooze.scheduledAt.toIso8601String(),
        'snooze_until': snooze.until.toIso8601String(),
      },
    );
    await _cache.put(key, jsonEncode(snooze.toJson()));
    return snooze;
  }

  /// Sends one queued snooze, and reads it back.
  ///
  /// Sent even if it has already run out by the time there is a network. A
  /// lapsed row is harmless — the cron only honours `snooze_until > now()` —
  /// and one that lapsed in the last ten minutes produces the single
  /// "time's up" reminder the snooze promised.
  Future<void> sendQueuedSnooze(OutboxEntry entry) async {
    final stored = await _remote.snoozeReturning(entry.payload);
    final wanted = readInstant(entry.payload['snooze_until']);
    final got = readInstant(stored?['snooze_until']);

    // Later is fine: the bot may have put the same dose off again since. What
    // is not fine is no row, or a snooze that ends before the one asked for —
    // then the server is still going to remind about a dose the screen says
    // is quiet.
    if (wanted == null || got == null || got.isBefore(wanted)) {
      throw StateError(
        'zad_dose_snoozes read back snooze_until $got after writing $wanted',
      );
    }
  }

  /// Whether this slot is being put off at [now].
  bool isSnoozed(String medicineId, DateTime scheduledAt, DateTime now) {
    final raw = _cache.get(DoseSnooze.keyFor(medicineId, scheduledAt));
    if (raw == null) return false;

    try {
      final snooze = DoseSnooze.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return snooze.coversAt(now);
    } on Object {
      return false;
    }
  }

  /// Drops snoozes that have expired.
  Future<void> pruneSnoozes(DateTime now) async {
    final dead = <String>[];
    for (final key in _cache.keys) {
      if (key is! String || !key.startsWith('snooze:')) continue;
      final raw = _cache.get(key);
      if (raw == null) continue;
      try {
        final snooze = DoseSnooze.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (!snooze.coversAt(now)) dead.add(key);
      } on Object {
        dead.add(key);
      }
    }
    await _cache.deleteAll(dead);
  }

  /// Removes a medicine.
  Future<void> remove(String id) async {
    await _cache.delete('$_medicinePrefix$id');
    await _outbox().enqueue(
      id: 'pharmacy_delete:$id',
      kind: OutboxKind.deletePharmacyItem,
      payload: <String, dynamic>{'id': id},
    );
  }

  /// Sends one queued medicine write.
  Future<void> sendQueued(OutboxEntry entry) async {
    final stored = await _remote.upsertReturning(entry.payload);
    if (stored == null) return;

    final confirmed = Medicine.fromJson(stored).markPending(pending: false);
    await _cache.put(
      '$_medicinePrefix${confirmed.id}',
      jsonEncode(confirmed.toCacheJson()),
    );
  }

  /// Sends one queued dose.
  ///
  /// A refusal the server can explain — `not_found`, `invalid_input` — is
  /// thrown rather than swallowed, so the outbox records a dead letter the
  /// customer can be shown. A dose that silently failed to record is the one
  /// outcome this path must not produce.
  Future<void> sendQueuedDose(OutboxEntry entry) async {
    final payload = entry.payload;
    final receipt = await _remote.logDose(
      userId: payload['user_id'] as String,
      medicineId: payload['item_id'] as String,
      scheduledAt: switch (payload['scheduled_at']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
      takenAt: DateTime.parse(payload['taken_at'] as String),
    );

    if (!receipt.ok) {
      throw StateError(
        'zad_log_pharmacy_dose_atomic refused: ${receipt.reason ?? 'unknown'}',
      );
    }

    // The count moved on the server. Reflect it locally rather than waiting
    // for a refresh, so the screen that just recorded a dose shows what is
    // left. A duplicate answers with the unchanged figure, which is correct.
    final remaining = receipt.remainingQuantity;
    if (remaining == null) return;

    final key = '$_medicinePrefix${payload['item_id']}';
    final current = _read(_cache.get(key) ?? '');
    if (current == null) return;
    await _cache.put(
      key,
      jsonEncode(current.copyWith(remainingQuantity: remaining).toCacheJson()),
    );
  }

  /// Sends one queued delete.
  Future<void> sendQueuedDelete(OutboxEntry entry) =>
      _remote.remove(entry.payload['id'] as String);

  /// Forgets the pharmacy. Called on sign-out.
  Future<void> clear() => _cache.clear();

  Future<void> _save(Medicine medicine) async {
    await _cache.put(
      '$_medicinePrefix${medicine.id}',
      jsonEncode(medicine.toCacheJson()),
    );
    await _outbox().enqueue(
      id: 'pharmacy:${medicine.id}',
      kind: OutboxKind.upsertPharmacyItem,
      payload: medicine.toUpsertJson(),
    );
  }

  static Medicine? _read(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Medicine.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  String _requireUserId() {
    final id = _signedInUserId();
    if (id == null || id.isEmpty) {
      throw StateError('no signed-in user to read or write a pharmacy for');
    }
    return id;
  }
}
