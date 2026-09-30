/// «أماكني»: place reminders, the outings زاد recorded, and what it learned
/// from them.
///
/// The place reminders lived on the appointments page and the outings nowhere
/// the customer could see; location is the brain's, not a page's (owner,
/// 2026-09-30). The outings come from `zad_place_visits`: leaving home and
/// coming back, the spend in between and the shops walked into — **never
/// coordinates** (home's position stays on the phone, see
/// `shared/places/domain/places.dart`).
library;

/// The places a place reminder can wait for. Stored values.
const List<String> kPlaceReminderPlaces = <String>[
  'pharmacy',
  'supermarket',
  'mall',
  'any',
];

/// One place reminder.
typedef PlaceReminder = ({String id, String note, String place});

/// Reads a `zad_place_reminders` row.
PlaceReminder placeReminderFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  note: (j['note'] as String?) ?? '',
  place: (j['place'] as String?) ?? 'any',
);

/// Place names.
String placeLabel(String place) => switch (place) {
  'pharmacy' => 'صيدلية',
  'supermarket' => 'سوبرماركت',
  'mall' => 'مول',
  _ => 'أي محل',
};

/// One outing: out of home and back.
typedef PlaceVisit = ({
  String id,
  DateTime leftAt,
  DateTime returnedAt,
  double spent,
  String? currency,
  List<String> merchants,
  List<String> stores,
});

List<String> _strings(Object? raw) => <String>[
  if (raw is List)
    for (final x in raw)
      if (x is String && x.trim().isNotEmpty) x.trim(),
];

/// Reads a `zad_place_visits` row, or null when its times are unreadable.
PlaceVisit? placeVisitFromJson(Map<String, dynamic> j) {
  final left = DateTime.tryParse('${j['left_at']}');
  final back = DateTime.tryParse('${j['returned_at']}');
  if (left == null || back == null) return null;
  return (
    id: '${j['id']}',
    leftAt: left.toUtc(),
    returnedAt: back.toUtc(),
    spent: (j['spent_total'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String?,
    merchants: _strings(j['merchants']),
    stores: _strings(j['stores']),
  );
}

/// A shop the customer keeps going back to.
typedef PlaceHabit = ({
  String name,
  int visits,

  /// The weekday most visits fell on (DateTime.monday … sunday), or null when
  /// no day stands out.
  int? usualWeekday,
});

/// The shops that turned up in at least [minVisits] outings, most visited
/// first. A weekday is "usual" when at least half the visits fell on it.
/// [toLocal] turns a UTC instant into the account's civil time.
List<PlaceHabit> placeHabits(
  List<PlaceVisit> visits,
  DateTime Function(DateTime utc) toLocal, {
  int minVisits = 2,
}) {
  final days = <String, List<int>>{};
  for (final v in visits) {
    final weekday = toLocal(v.leftAt).weekday;
    for (final name in <String>{...v.stores, ...v.merchants}) {
      (days[name] ??= <int>[]).add(weekday);
    }
  }
  final habits = <PlaceHabit>[
    for (final MapEntry(key: name, value: list) in days.entries)
      if (list.length >= minVisits)
        (name: name, visits: list.length, usualWeekday: _usual(list)),
  ]..sort((a, b) => b.visits.compareTo(a.visits));
  return habits;
}

int? _usual(List<int> weekdays) {
  final counts = <int, int>{};
  for (final d in weekdays) {
    counts[d] = (counts[d] ?? 0) + 1;
  }
  final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
  return top.value * 2 >= weekdays.length ? top.key : null;
}

/// Arabic weekday names, Monday first.
String weekdayLabel(int weekday) => const <String>[
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
  'السبت',
  'الحد',
][weekday - 1];
