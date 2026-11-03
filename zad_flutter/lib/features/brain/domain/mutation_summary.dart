/// One line a person can read for one of the brain's edits, from the
/// `old`/`new` pair `zad_brain_runs.mutations` keeps.
///
/// Many tools store whole rows on both sides (`update_pharmacy_item` keeps the
/// row before and after), and the sheet printed them as JSON — ids, nulls and
/// all, the owner's screenshot of 2026-10-13. A row is now its name plus the
/// fields that actually changed, by their Arabic names.
library;

import 'dart:convert';

import 'package:zad/core/l10n/l10n.dart';

/// What changed: the thing's name, and the change itself.
typedef MutationSummary = ({String? subject, String? change});

/// The fields a row is named by, most telling first.
const List<String> _subjectKeys = <String>[
  'name',
  'title',
  'item_name',
  'item',
  'subject',
  'description',
  'merchant',
];

/// Fields shown, in the order they are listed. Anything else in a row is
/// plumbing (ids, timestamps, flags) and is left out.
const List<String> _fieldKeys = <String>[
  'amount',
  'quantity',
  'qty',
  'remaining_quantity',
  'remaining_balance',
  'price',
  'unit',
  'category',
  'kind',
  'status',
  'starts_at',
  'run_at',
  'task_description',
  'recurrence',
  'dosage',
  'dose_times',
  'daily_dose_count',
  'expiry_date',
  'expires_on',
  'renewal_date',
  'due_day',
  'billing_cycle',
  'is_active',
  'for_person',
  'place',
  'place_label',
  'note',
  'notes',
  'expected_cost',
  'currency',
  'country',
  'pay_day',
  'bed',
  'wake',
  'daily_cap',
  'length_days',
  'trade',
  'metric',
];

String _fieldLabel(String key, ZadL10n l) => switch (key) {
  'amount' => l.mutationFieldAmount,
  'quantity' => l.mutationFieldQuantity,
  'qty' => l.mutationFieldQuantity,
  'remaining_quantity' => l.mutationFieldRemainingQuantity,
  'remaining_balance' => l.mutationFieldRemainingBalance,
  'price' => l.mutationFieldPrice,
  'unit' => l.mutationFieldUnit,
  'category' => l.mutationFieldCategory,
  'kind' => l.mutationFieldKind,
  'status' => l.mutationFieldStatus,
  'starts_at' => l.mutationFieldStartsAt,
  'run_at' => l.mutationFieldStartsAt,
  'task_description' => l.mutationFieldTaskDescription,
  'recurrence' => l.mutationFieldRecurrence,
  'dosage' => l.mutationFieldDosage,
  'dose_times' => l.mutationFieldDoseTimes,
  'daily_dose_count' => l.mutationFieldDailyDoseCount,
  'expiry_date' => l.mutationFieldExpiryDate,
  'expires_on' => l.mutationFieldExpiryDate,
  'renewal_date' => l.mutationFieldRenewalDate,
  'due_day' => l.mutationFieldDueDay,
  'billing_cycle' => l.mutationFieldBillingCycle,
  'is_active' => l.mutationFieldIsActive,
  'for_person' => l.mutationFieldForPerson,
  'place' => l.mutationFieldPlace,
  'place_label' => l.mutationFieldPlace,
  'note' => l.mutationFieldNote,
  'notes' => l.mutationFieldNotes,
  'expected_cost' => l.mutationFieldExpectedCost,
  'currency' => l.mutationFieldCurrency,
  'country' => l.mutationFieldCountry,
  'pay_day' => l.mutationFieldPayDay,
  'bed' => l.mutationFieldBed,
  'wake' => l.mutationFieldWake,
  'daily_cap' => l.mutationFieldDailyCap,
  'length_days' => l.mutationFieldLengthDays,
  'trade' => l.mutationFieldTrade,
  'metric' => l.mutationFieldMetric,
  _ => key,
};

String? _statusLabel(String status, ZadL10n l) => switch (status) {
  'upcoming' => l.mutationStatusUpcoming,
  'done' => l.mutationStatusDone,
  'cancelled' => l.mutationStatusCancelled,
  'active' => l.mutationStatusActive,
  'abandoned' => l.mutationStatusAbandoned,
  _ => null,
};

/// At most this many fields on one line.
const int _maxFields = 3;

/// The readable form of one mutation. [toLocal] turns a UTC instant into the
/// account's civil time. [l10n] = the customer's language (Arabic when
/// absent).
MutationSummary summarizeMutation(
  Object? old,
  Object? next, {
  required DateTime Function(DateTime utc) toLocal,
  ZadL10n? l10n,
}) {
  final l = l10n ?? zadL10nArabic;
  String value(Object? v, [String? key]) =>
      _value(v, key: key, toLocal: toLocal, l: l);

  final subject = _subjectOf(next) ?? _subjectOf(old);

  // A row on each side: only what differs.
  if (old is Map && next is Map) {
    String diff(String key) => l.mutationFieldChange(
      _fieldLabel(key, l),
      value(old[key], key),
      value(next[key], key),
    );
    final changed = <String>[
      for (final key in _fieldKeys)
        if ((old.containsKey(key) || next.containsKey(key)) &&
            jsonEncode(old[key]) != jsonEncode(next[key]))
          diff(key),
    ];
    return (subject: subject, change: _join(changed, l) ?? l.mutationEdited);
  }

  // Something new: what it was created with.
  if (old == null && next is Map) {
    return (subject: subject, change: _join(_fields(next, value, l), l));
  }

  // Something removed.
  if (old is Map && next == null) {
    return (subject: subject, change: l.mutationRemoved);
  }

  // A plain value on at least one side; a row on the other side is read as
  // its one field that is not its name (`{item, qty}` → the qty).
  String side(Object? v) => v is Map ? _soleValue(v, value, l) : value(v);
  if (old == null) return (subject: subject, change: side(next));
  return (
    subject: subject,
    change: l.mutationValueChange(side(old), side(next)),
  );
}

String? _subjectOf(Object? v) {
  if (v is! Map) return null;
  for (final key in _subjectKeys) {
    final s = v[key];
    if (s is String && s.trim().isNotEmpty) return s.trim();
  }
  return null;
}

List<String> _fields(
  Map<dynamic, dynamic> row,
  String Function(Object?, [String?]) value,
  ZadL10n l,
) => <String>[
  for (final key in _fieldKeys)
    if (row[key] != null) '${_fieldLabel(key, l)}: ${value(row[key], key)}',
];

String _soleValue(
  Map<dynamic, dynamic> row,
  String Function(Object?, [String?]) value,
  ZadL10n l,
) {
  final rest = <MapEntry<dynamic, dynamic>>[
    for (final e in row.entries)
      if (!_subjectKeys.contains(e.key) && e.value != null) e,
  ];
  if (rest.length == 1) return value(rest.single.value, '${rest.single.key}');
  return _join(_fields(row, value, l), l) ?? '—';
}

String? _join(List<String> parts, ZadL10n l) {
  if (parts.isEmpty) return null;
  final shown = parts.take(_maxFields).join(' • ');
  final more = parts.length - _maxFields;
  return more > 0 ? l.mutationMore(shown, more) : shown;
}

String _value(
  Object? v, {
  required DateTime Function(DateTime utc) toLocal,
  required ZadL10n l,
  String? key,
}) => switch (v) {
  null => '—',
  true => l.mutationYes,
  false => l.mutationNo,
  final num n => n == n.roundToDouble() ? '${n.toInt()}' : '$n',
  final String s when key == 'status' => _statusLabel(s, l) ?? s,
  final String s => _instant(s, toLocal) ?? _clip(s),
  final List<dynamic> items when items.every((e) => e is String || e is num) =>
    _clip(items.join(l.mutationListSeparator)),
  final List<dynamic> items => l.mutationItems(items.length),
  final Map<dynamic, dynamic> m => _subjectOf(m) ?? '…',
  _ => '…',
};

/// `2026-10-12T03:30:00.000Z` as `12/10 06:30` on the account's clock. A bare
/// date (`2026-10-27`) has no instant to move and stays as it is.
String? _instant(String s, DateTime Function(DateTime utc) toLocal) {
  if (!s.contains('T')) return null;
  final at = DateTime.tryParse(s);
  if (at == null) return null;
  final local = toLocal(at.toUtc());
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.day}/${local.month} ${two(local.hour)}:${two(local.minute)}';
}

String _clip(String s) => s.length <= 40 ? s : '${s.substring(0, 39)}…';
