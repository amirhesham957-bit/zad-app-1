/// One medicine being tracked.
///
/// Mirrors `zad_pharmacy_items`. Several columns are the server's arithmetic
/// and are read but never sent: `dose_carry`, which holds the fraction left
/// over when a dose is less than a whole unit, and `remaining_quantity`, which
/// `zad_log_pharmacy_dose_atomic` decrements inside the same transaction that
/// records the dose. A client that wrote either would be racing the RPC for
/// the same number.
library;

import 'package:zad/features/pharmacy/domain/dose_time.dart';

/// A tracked medicine.
class Medicine {
  /// Creates a medicine.
  const new({
    required this.id,
    required this.userId,
    required this.name,
    this.dosage,
    this.activeIngredient,
    this.category,
    this.unit,
    this.doseTimesRaw,
    this.dailyDoseCount,
    this.unitsPerDose = 1,
    this.remainingQuantity,
    this.doseCarry = 0,
    this.expiryDate,
    this.familyMemberId,
    this.serverSaysInvalidDoseTime = false,
    this.isRecurring = true,
    this.isPending = false,
  });

  /// Reads a server row.
  factory fromJson(Map<String, dynamic> json) => Medicine(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    name: (json['name'] as String?)?.trim() ?? '',
    dosage: json['dosage'] as String?,
    activeIngredient: json['active_ingredient'] as String?,
    category: json['category'] as String?,
    unit: json['unit'] as String?,
    doseTimesRaw: json['dose_times'] as String?,
    dailyDoseCount: (json['daily_dose_count'] as num?)?.toInt(),
    unitsPerDose: (json['units_per_dose'] as num?)?.toDouble() ?? 1,
    remainingQuantity: (json['remaining_quantity'] as num?)?.toInt(),
    doseCarry: (json['dose_carry'] as num?)?.toDouble() ?? 0,
    expiryDate: _date(json['expiry_date']),
    familyMemberId: json['family_member_id'] as String?,
    serverSaysInvalidDoseTime: json['has_invalid_dose_time'] as bool? ?? false,
    isRecurring: json['is_recurring'] as bool? ?? true,
    isPending: json['_pending'] as bool? ?? false,
  );

  /// The row id.
  final String id;

  /// Whose medicine.
  final String userId;

  /// What it is called.
  final String name;

  /// Strength and instructions — `500mg`, `بعد الأكل`.
  ///
  /// Never the frequency. The schedule lives in [doseTimesRaw] and
  /// [dailyDoseCount], and the agent's prompt says so explicitly, because a
  /// dosage string that also said "every 8 hours" produced two schedules that
  /// could disagree.
  final String? dosage;

  /// The active ingredient, when the scanner read one.
  final String? activeIngredient;

  /// `مزمن`, `مسكن`, `مضاد حيوي` — stored, so Arabic.
  final String? category;

  /// `قرص`, `مل`, `كريم` — stored, so Arabic.
  final String? unit;

  /// The raw `dose_times` column, kept verbatim.
  ///
  /// Held as written rather than as a parsed list so a row with a bad entry
  /// round-trips unchanged instead of being quietly rewritten by this client.
  final String? doseTimesRaw;

  /// How many doses a day the schedule is meant to have.
  final int? dailyDoseCount;

  /// How much of [unit] one dose takes. May be fractional — half a tablet.
  final double unitsPerDose;

  /// How many units are left, or null when nobody has counted.
  final int? remainingQuantity;

  /// The fraction of a unit carried from previous doses. The server's.
  final double doseCarry;

  /// When it expires, as a civil date.
  final DateTime? expiryDate;

  /// Which family member it belongs to, when it is not the account holder's.
  final String? familyMemberId;

  /// What the row's own `has_invalid_dose_time` flag says.
  ///
  /// The cron filters on this, so a row flagged here is one the server will
  /// never remind anybody about — whatever the column now contains.
  final bool serverSaysInvalidDoseTime;

  /// Whether this is an ongoing course rather than a one-off.
  final bool isRecurring;

  /// Whether the row is still queued.
  final bool isPending;

  /// The valid times in the schedule, in order.
  List<DoseTime> get doseTimes => parseDoseTimes(doseTimesRaw);

  /// Whether the column holds anything the server would refuse.
  bool get hasUnreadableDoseTime => hasInvalidDoseTime(doseTimesRaw);

  /// Whether this medicine can produce a reminder at all.
  ///
  /// The three conditions the cron applies, in the same order: a schedule,
  /// no invalid-time flag, and something left to take. A medicine failing any
  /// of them is silent on the server, and a screen that showed its doses as
  /// due would be promising an alert that is not coming.
  bool get isScheduled =>
      doseTimes.isNotEmpty &&
      !serverSaysInvalidDoseTime &&
      (remainingQuantity == null || remainingQuantity! > 0);

  /// Whether it has run out.
  bool get isOutOfStock => remainingQuantity != null && remainingQuantity! <= 0;

  /// Whether there is roughly less than a day's worth left.
  ///
  /// The same comparison `zad_log_pharmacy_dose_atomic` makes before it puts
  /// the medicine on the shopping list: `remaining <= ceil(daily_dose_count *
  /// units_per_dose)`.
  bool get isRunningOut {
    final remaining = remainingQuantity;
    if (remaining == null || remaining <= 0) return false;

    final perDay = (dailyDoseCount ?? 1) < 1 ? 1 : (dailyDoseCount ?? 1);
    final units = unitsPerDose <= 0 ? 1.0 : unitsPerDose;
    return remaining <= (perDay * units).ceil();
  }

  /// A copy with the given fields replaced.
  Medicine copyWith({
    String? name,
    String? dosage,
    String? category,
    String? unit,
    String? doseTimesRaw,
    int? dailyDoseCount,
    double? unitsPerDose,
    int? remainingQuantity,
    DateTime? expiryDate,
    bool? isPending,
  }) => Medicine(
    id: id,
    userId: userId,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    activeIngredient: activeIngredient,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    doseTimesRaw: doseTimesRaw ?? this.doseTimesRaw,
    dailyDoseCount: dailyDoseCount ?? this.dailyDoseCount,
    unitsPerDose: unitsPerDose ?? this.unitsPerDose,
    remainingQuantity: remainingQuantity ?? this.remainingQuantity,
    doseCarry: doseCarry,
    expiryDate: expiryDate ?? this.expiryDate,
    familyMemberId: familyMemberId,
    serverSaysInvalidDoseTime: serverSaysInvalidDoseTime,
    isRecurring: isRecurring,
    isPending: isPending ?? this.isPending,
  );

  /// Marks the row queued, or settled.
  Medicine markPending({required bool pending}) => copyWith(isPending: pending);

  /// The row to send.
  ///
  /// `dose_carry`, `remaining_quantity` and `has_invalid_dose_time` are left
  /// out: the first two are the dose RPC's to move, and the third is set when
  /// the server validates the schedule.
  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'name': name,
    'dosage': ?dosage,
    'category': ?category,
    'unit': ?unit,
    'dose_times': ?doseTimesRaw,
    'daily_dose_count': ?dailyDoseCount,
    'units_per_dose': unitsPerDose,
    'expiry_date': expiryDate?.toIso8601String().split('T').first,
  };

  /// The row as the cache keeps it.
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
    ...toUpsertJson(),
    'active_ingredient': ?activeIngredient,
    'remaining_quantity': remainingQuantity,
    'dose_carry': doseCarry,
    'family_member_id': ?familyMemberId,
    'has_invalid_dose_time': serverSaysInvalidDoseTime,
    'is_recurring': isRecurring,
    '_pending': isPending,
  };
}

DateTime? _date(Object? value) => switch (value) {
  final String s when s.isNotEmpty => DateTime.parse(
    '${s.split('T').first}T00:00:00Z',
  ),
  _ => null,
};
