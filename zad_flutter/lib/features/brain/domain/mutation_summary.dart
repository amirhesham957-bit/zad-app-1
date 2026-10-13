/// One line a person can read for one of the brain's edits, from the
/// `old`/`new` pair `zad_brain_runs.mutations` keeps.
///
/// Many tools store whole rows on both sides (`update_pharmacy_item` keeps the
/// row before and after), and the sheet printed them as JSON — ids, nulls and
/// all, the owner's screenshot of 2026-10-13. A row is now its name plus the
/// fields that actually changed, by their Arabic names.
library;

import 'dart:convert';

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

/// Fields shown, by their Arabic names. Anything else in a row is plumbing
/// (ids, timestamps, flags) and is left out.
const Map<String, String> _fieldLabels = <String, String>{
  'amount': 'المبلغ',
  'quantity': 'الكمية',
  'qty': 'الكمية',
  'remaining_quantity': 'الكمية المتبقية',
  'remaining_balance': 'المتبقي',
  'price': 'السعر',
  'unit': 'الوحدة',
  'category': 'الفئة',
  'kind': 'النوع',
  'status': 'الحالة',
  'starts_at': 'الميعاد',
  'run_at': 'الميعاد',
  'task_description': 'التذكير',
  'recurrence': 'التكرار',
  'dosage': 'الجرعة',
  'dose_times': 'مواعيد الجرعات',
  'daily_dose_count': 'جرعات اليوم',
  'expiry_date': 'الصلاحية',
  'expires_on': 'الصلاحية',
  'renewal_date': 'التجديد',
  'due_day': 'يوم الاستحقاق',
  'billing_cycle': 'الدورة',
  'is_active': 'شغّال',
  'for_person': 'لمين',
  'place': 'المكان',
  'place_label': 'المكان',
  'note': 'ملاحظة',
  'notes': 'ملاحظات',
  'expected_cost': 'التكلفة المتوقعة',
  'currency': 'العملة',
  'country': 'البلد',
  'pay_day': 'يوم القبض',
  'bed': 'النوم',
  'wake': 'الصحيان',
  'daily_cap': 'سقف اليوم',
  'length_days': 'المدة بالأيام',
  'trade': 'الصنعة',
  'metric': 'المقياس',
};

const Map<String, String> _statusLabels = <String, String>{
  'upcoming': 'جاي',
  'done': 'خلص',
  'cancelled': 'اتلغى',
  'active': 'شغّال',
  'abandoned': 'اتوقف',
};

/// At most this many fields on one line.
const int _maxFields = 3;

/// The readable form of one mutation. [toLocal] turns a UTC instant into the
/// account's civil time.
MutationSummary summarizeMutation(
  Object? old,
  Object? next, {
  required DateTime Function(DateTime utc) toLocal,
}) {
  String value(Object? v, [String? key]) =>
      _value(v, key: key, toLocal: toLocal);

  final subject = _subjectOf(next) ?? _subjectOf(old);

  // A row on each side: only what differs.
  if (old is Map && next is Map) {
    String diff(String key) =>
        '${_fieldLabels[key]}: ${value(old[key], key)} ← '
        '${value(next[key], key)}';
    final changed = <String>[
      for (final key in _fieldLabels.keys)
        if ((old.containsKey(key) || next.containsKey(key)) &&
            jsonEncode(old[key]) != jsonEncode(next[key]))
          diff(key),
    ];
    return (subject: subject, change: _join(changed) ?? 'اتعدّل');
  }

  // Something new: what it was created with.
  if (old == null && next is Map) {
    return (subject: subject, change: _join(_fields(next, value)));
  }

  // Something removed.
  if (old is Map && next == null) return (subject: subject, change: 'اتشال');

  // A plain value on at least one side; a row on the other side is read as
  // its one field that is not its name (`{item, qty}` → the qty).
  String side(Object? v) => v is Map ? _soleValue(v, value) : value(v);
  if (old == null) return (subject: subject, change: side(next));
  return (subject: subject, change: '${side(old)} ← ${side(next)}');
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
) => <String>[
  for (final key in _fieldLabels.keys)
    if (row[key] != null) '${_fieldLabels[key]}: ${value(row[key], key)}',
];

String _soleValue(
  Map<dynamic, dynamic> row,
  String Function(Object?, [String?]) value,
) {
  final rest = <MapEntry<dynamic, dynamic>>[
    for (final e in row.entries)
      if (!_subjectKeys.contains(e.key) && e.value != null) e,
  ];
  if (rest.length == 1) return value(rest.single.value, '${rest.single.key}');
  return _join(_fields(row, value)) ?? '—';
}

String? _join(List<String> parts) {
  if (parts.isEmpty) return null;
  final shown = parts.take(_maxFields).join(' • ');
  final more = parts.length - _maxFields;
  return more > 0 ? '$shown • و$more كمان' : shown;
}

String _value(
  Object? v, {
  required DateTime Function(DateTime utc) toLocal,
  String? key,
}) => switch (v) {
  null => '—',
  true => 'أيوه',
  false => 'لأ',
  final num n => n == n.roundToDouble() ? '${n.toInt()}' : '$n',
  final String s when key == 'status' => _statusLabels[s] ?? s,
  final String s => _instant(s, toLocal) ?? _clip(s),
  final List<dynamic> l when l.every((e) => e is String || e is num) => _clip(
    l.join('، '),
  ),
  final List<dynamic> l => '${l.length} عناصر',
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
