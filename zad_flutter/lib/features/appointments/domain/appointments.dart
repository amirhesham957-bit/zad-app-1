/// مواعيدي — Kotlin's `Appointments.kt`: non-money appointments and errands
/// (`zad_appointments`) and reminders tied to a kind of place rather than a
/// time (`zad_place_reminders`). The reminder itself is spoken by the server;
/// nothing here schedules an alarm on the phone.
library;

/// The kinds the table accepts.
const List<String> kAppointmentKinds = <String>[
  'work',
  'errand',
  'medical',
  'family',
  'personal',
  'other',
];

/// The places a place reminder can wait for.
const List<String> kPlaceReminderPlaces = <String>[
  'pharmacy',
  'supermarket',
  'mall',
  'any',
];

/// The repeat choices.
const List<String> kRecurrences = <String>[
  'once',
  'hourly',
  'daily',
  'weekly',
  'monthly',
];

/// One appointment.
typedef Appointment = ({
  String id,
  String title,
  String kind,
  DateTime? startsAt,
  String startsAtRaw,
  String? placeLabel,
  String recurrence,
  String status,
});

/// Reads a row.
Appointment appointmentFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  title: (j['title'] as String?) ?? '',
  kind: (j['kind'] as String?) ?? 'other',
  startsAt: DateTime.tryParse('${j['starts_at']}'),
  startsAtRaw: '${j['starts_at']}',
  placeLabel: j['place_label'] as String?,
  recurrence: (j['recurrence'] as String?) ?? 'once',
  status: (j['status'] as String?) ?? 'upcoming',
);

/// One place reminder.
typedef PlaceReminder = ({String id, String note, String place});

/// Reads a row.
PlaceReminder placeReminderFromJson(Map<String, dynamic> j) => (
  id: '${j['id']}',
  note: (j['note'] as String?) ?? '',
  place: (j['place'] as String?) ?? 'any',
);

/// The list's sections, in order.
enum AppointmentGroup {
  /// Today.
  today('النهارده'),

  /// Tomorrow.
  tomorrow('بكرة'),

  /// Within a week.
  thisWeek('الأسبوع ده'),

  /// Further out.
  later('بعد كده'),

  /// Done or gone.
  past('اللي فات');

  new(this.label);

  /// Heading.
  final String label;
}

/// Kotlin's `groupAppointments`, in [toLocal] civil time: done or already
/// past → past (newest first); otherwise by days from today.
List<(AppointmentGroup, List<Appointment>)> groupAppointments(
  List<Appointment> items,
  DateTime nowLocal,
  DateTime Function(DateTime utc) toLocal,
) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final dated = <(Appointment, DateTime)>[
    for (final a in items)
      if (a.status != 'cancelled' && a.startsAt != null)
        (a, toLocal(a.startsAt!)),
  ]..sort((x, y) => x.$2.compareTo(y.$2));
  final grouped = <AppointmentGroup, List<Appointment>>{};
  for (final (a, at) in dated) {
    final day = DateTime(at.year, at.month, at.day);
    final days = day.difference(today).inDays;
    final g = a.status == 'done' || at.isBefore(nowLocal)
        ? AppointmentGroup.past
        : days == 0
        ? AppointmentGroup.today
        : days == 1
        ? AppointmentGroup.tomorrow
        : days <= 7
        ? AppointmentGroup.thisWeek
        : AppointmentGroup.later;
    (grouped[g] ??= <Appointment>[]).add(a);
  }
  return <(AppointmentGroup, List<Appointment>)>[
    for (final g in AppointmentGroup.values)
      if (grouped[g] case final list?)
        (g, g == AppointmentGroup.past ? list.reversed.toList() : list),
  ];
}

/// Kind names.
String kindLabel(String kind) => switch (kind) {
  'work' => 'شغل',
  'errand' => 'مشوار',
  'medical' => 'دكتور وصحة',
  'family' => 'عيلة',
  'personal' => 'شخصي',
  _ => 'تاني',
};

/// Repeat names.
String recurrenceLabel(String r) => switch (r) {
  'hourly' => 'كل ساعة',
  'daily' => 'كل يوم',
  'weekly' => 'كل أسبوع',
  'monthly' => 'كل شهر',
  _ => 'مرة واحدة',
};

/// Place names.
String placeLabel(String place) => switch (place) {
  'pharmacy' => 'صيدلية',
  'supermarket' => 'سوبرماركت',
  'mall' => 'مول',
  _ => 'أي محل',
};
