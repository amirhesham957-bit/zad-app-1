/// The pharmacy screen's state.
///
/// Today's doses are computed here and nowhere else in the UI, in the
/// account's market zone, by the same `doseSlotsFor` the tests hold to the
/// cron. The screen never builds a slot itself.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// What the pharmacy screen draws.
class PharmacyView {
  /// Creates a view.
  const new({
    this.medicines = const <Medicine>[],
    this.today = const <DoseSlot>[],
    this.snoozed = const <String>{},
    this.adherence,
    this.isRefreshing = false,
    this.error,
  });

  /// Every medicine, by name.
  final List<Medicine> medicines;

  /// The doses that matter now — today's, plus yesterday's still inside the
  /// answer window — in order.
  final List<DoseSlot> today;

  /// Slots put off on this device, keyed as `DoseSnooze.keyFor`.
  final Set<String> snoozed;

  /// The last seven days' taken share, 0..100 — null until a dose has come
  /// due. Home's pharmacy card shows it.
  final int? adherence;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// The last refresh failure.
  final Object? error;

  /// Whether nothing is being tracked.
  bool get isEmpty => medicines.isEmpty;

  /// A copy with the given fields replaced.
  PharmacyView copyWith({
    List<Medicine>? medicines,
    List<DoseSlot>? today,
    Set<String>? snoozed,
    int? adherence,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) => PharmacyView(
    medicines: medicines ?? this.medicines,
    today: today ?? this.today,
    snoozed: snoozed ?? this.snoozed,
    adherence: adherence ?? this.adherence,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the pharmacy.
class PharmacyController extends Notifier<PharmacyView> {
  bool _fetching = false;

  @override
  PharmacyView build() {
    final medicines = ref.read(pharmacyRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    // Slots without records until the refresh lands. They read as due or
    // upcoming rather than taken, which errs towards asking — the safer way
    // to be wrong about a medicine for a second.
    return PharmacyView(medicines: medicines, today: _bareSlots(medicines));
  }

  /// Fetches the medicines and the doses already recorded.
  Future<void> refresh() async {
    if (_fetching || !ref.mounted) return;
    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final repository = ref.read(pharmacyRepositoryProvider);
      final medicines = await repository.refresh();
      final now = ref.read(nowProvider)();
      final zone = ref.read(accountTimeZoneProvider);

      final slots = <DoseSlot>[
        for (final medicine in medicines)
          ...await repository.slotsFor(
            medicine,
            now: now,
            timeZone: zone,
            daysBack: 7,
          ),
      ];
      await repository.pruneSnoozes(now);
      if (!ref.mounted) return;

      state = PharmacyView(
        medicines: medicines,
        today: _relevant(slots, now),
        snoozed: _snoozedAmong(slots, now),
        adherence: weeklyAdherence(slots, now),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isRefreshing: false, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Kotlin's `AddPharmacyItemDialog`: the medicine, then its count.
  ///
  /// The plain upsert never carries `remaining_quantity` (the dose RPC owns
  /// that column), so the count the customer typed follows as a queued
  /// confirmation — the same write "فاضل قد إيه فعلاً؟" makes.
  Future<void> add({
    required String name,
    required int quantity,
    required String unit,
    required int dailyDoseCount,
    String? doseTimes,
    DateTime? expiryDate,
    double price = 0,
    String? activeIngredient,
    String? dosage,
    String? category,
    bool isRecurring = false,
    String? familyMemberId,
  }) async {
    final repository = ref.read(pharmacyRepositoryProvider);
    final added = await repository.add(
      name: name,
      dosage: dosage,
      category: category,
      unit: unit,
      doseTimes: doseTimes,
      dailyDoseCount: dailyDoseCount,
      remainingQuantity: quantity,
      expiryDate: expiryDate,
    );
    await repository.update(
      added.copyWith(
        price: price,
        activeIngredient: activeIngredient,
        isRecurring: isRecurring,
        familyMemberId: familyMemberId,
      ),
    );
    await repository.confirmQuantity(added.id, quantity);
    await _afterWrite();
  }

  /// "تجديد الطلب": [added] more in stock, and the new price and expiry when
  /// given.
  Future<void> refill(
    Medicine medicine, {
    required int added,
    double? price,
    DateTime? expiryDate,
  }) async {
    final repository = ref.read(pharmacyRepositoryProvider);
    if (price != null || expiryDate != null) {
      await repository.update(
        medicine.copyWith(price: price, expiryDate: expiryDate),
      );
    }
    await repository.restock(medicine.id, added);
    await _afterWrite();
  }

  /// "فاضل قد إيه فعلاً؟": the counted stock, and how many units one dose is
  /// when the customer said.
  Future<void> confirmQuantity(
    Medicine medicine,
    int quantity, {
    double? unitsPerDose,
  }) async {
    final repository = ref.read(pharmacyRepositoryProvider);
    if (unitsPerDose != null && unitsPerDose > 0) {
      await repository.update(medicine.copyWith(unitsPerDose: unitsPerDose));
    }
    await repository.confirmQuantity(medicine.id, quantity);
    await _afterWrite();
  }

  /// "تناول جرعة" on a medicine with no schedule: one dose, now.
  Future<void> takeNow(Medicine medicine) async {
    final now = ref.read(nowProvider)();
    await ref
        .read(pharmacyRepositoryProvider)
        .logDose(medicine.id, scheduledAt: now, takenAt: now);
    await _afterWrite();
  }

  /// Deletes a medicine.
  Future<void> remove(Medicine medicine) async {
    await ref.read(pharmacyRepositoryProvider).remove(medicine.id);
    await _afterWrite();
  }

  Future<void> _afterWrite() async {
    if (!ref.mounted) return;
    final medicines = ref.read(pharmacyRepositoryProvider).cached();
    state = state.copyWith(
      medicines: medicines,
      today: _relevant(_bareSlots(medicines), ref.read(nowProvider)()),
    );
    unawaited(
      ref.read(outboxProvider).flush().then((_) {}, onError: (Object _) {}),
    );
  }

  /// Records a dose against its slot.
  ///
  /// Marked taken on screen straight away. The write is queued; the slot is
  /// the customer's to answer and the answer should not wait on a network.
  Future<void> take(DoseSlot slot) async {
    final now = ref.read(nowProvider)();
    await ref
        .read(pharmacyRepositoryProvider)
        .logDose(slot.medicine.id, scheduledAt: slot.scheduledAt, takenAt: now);
    if (!ref.mounted) return;

    state = state.copyWith(
      today: <DoseSlot>[
        for (final s in state.today)
          if (_same(s, slot)) s.markTaken(now) else s,
      ],
    );
  }

  /// Puts a dose off — here at once, and for the server's reminders and the
  /// bot through the outbox.
  Future<void> snooze(DoseSlot slot) async {
    final now = ref.read(nowProvider)();
    await ref
        .read(pharmacyRepositoryProvider)
        .snooze(slot.medicine.id, scheduledAt: slot.scheduledAt, now: now);
    if (!ref.mounted) return;

    state = state.copyWith(snoozed: <String>{...state.snoozed, _keyOf(slot)});
  }

  /// Whether [slot] is being put off.
  bool isSnoozed(DoseSlot slot) => state.snoozed.contains(_keyOf(slot));

  List<DoseSlot> _bareSlots(List<Medicine> medicines) {
    final now = ref.read(nowProvider)();
    final zone = ref.read(accountTimeZoneProvider);
    return _relevant(<DoseSlot>[
      for (final medicine in medicines)
        ...doseSlotsFor(medicine, now: now, timeZone: zone),
    ], now);
  }

  /// Today's slots, and yesterday's only while they can still be answered.
  ///
  /// Yesterday is fetched because the cron looks at it, but a slot from
  /// yesterday morning is history, not a task; showing it would put a dose on
  /// today's list that nobody can take any more.
  static List<DoseSlot> _relevant(List<DoseSlot> slots, DateTime now) {
    final utcNow = now.toUtc();
    final earliest = utcNow.subtract(DoseSlot.takenWindow);
    final latest = utcNow.add(const Duration(hours: 24));
    return slots
        .where((s) => !s.scheduledAt.isBefore(earliest) || s.isTaken)
        .where((s) => s.scheduledAt.isBefore(latest))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Set<String> _snoozedAmong(List<DoseSlot> slots, DateTime now) {
    final repository = ref.read(pharmacyRepositoryProvider);
    return <String>{
      for (final slot in slots)
        if (repository.isSnoozed(slot.medicine.id, slot.scheduledAt, now))
          _keyOf(slot),
    };
  }

  static bool _same(DoseSlot a, DoseSlot b) =>
      a.medicine.id == b.medicine.id && a.scheduledAt == b.scheduledAt;

  static String _keyOf(DoseSlot slot) =>
      '${slot.medicine.id}:${slot.scheduledAt.toIso8601String()}';
}

/// The pharmacy.
final pharmacyControllerProvider =
    NotifierProvider<PharmacyController, PharmacyView>(PharmacyController.new);
