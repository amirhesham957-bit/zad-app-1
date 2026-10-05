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
  String? forPerson,
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
  forPerson: j['for_person'] as String?,
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

// ── حارس التوقيت (ZAD_LIVING_BRAIN.md الشريحة ٣٩) ─────────────────────────
// نفس قاعدة السيرفر (`zad-brain/scheduleGuard.ts`): ميعاد تاني لنفس الشخص
// في أقل من ساعة ⇒ تنبيه قبل الحفظ، مش منع. المتكرر بالساعة المحلية: يومي كل
// يوم، أسبوعي نفس يوم الأسبوع، شهري نفس اليوم في الشهر، من أول ما يبدأ.
// «كل ساعة» مابيتحسبش تعارض.

/// The window either side: appointments have no length.
const Duration kClashWindow = Duration(hours: 1);

String _person(String? s) => (s ?? '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .toLowerCase();

int _clockGap(DateTime a, DateTime b) {
  final d = ((a.hour * 60 + a.minute) - (b.hour * 60 + b.minute)).abs();
  return d < 1440 - d ? d : 1440 - d;
}

/// The upcoming appointments a new one at [startsAt] (an instant) would
/// sit on top of, for the same person. [toLocal] gives the account's civil
/// time.
List<Appointment> appointmentClashes({
  required DateTime startsAt,
  required String? forPerson,
  required String recurrence,
  required List<Appointment> existing,
  required DateTime Function(DateTime utc) toLocal,
}) {
  if (recurrence == 'hourly') return const <Appointment>[];
  final window = kClashWindow.inMinutes;
  final mine = toLocal(startsAt);
  return <Appointment>[
    for (final e in existing)
      if (e.status == 'upcoming' &&
          e.recurrence != 'hourly' &&
          e.startsAt != null &&
          _person(e.forPerson) == _person(forPerson) &&
          _clashes(e, startsAt, mine, window, toLocal))
        e,
  ];
}

bool _clashes(
  Appointment e,
  DateTime at,
  DateTime mine,
  int window,
  DateTime Function(DateTime utc) toLocal,
) {
  final theirs = e.startsAt!;
  if (e.recurrence == 'once') {
    return theirs.difference(at).inMinutes.abs() < window;
  }
  if (at.isBefore(theirs.subtract(kClashWindow))) return false;
  final local = toLocal(theirs);
  if (_clockGap(local, mine) >= window) return false;
  return switch (e.recurrence) {
    'daily' => true,
    'weekly' => local.weekday == mine.weekday,
    'monthly' => local.day == mine.day,
    _ => false,
  };
}

/// The line under the time in the add dialog.
String clashWarning(
  List<Appointment> clashes,
  DateTime Function(DateTime utc) toLocal,
) {
  String two(int n) => n.toString().padLeft(2, '0');
  String one(Appointment c) {
    final t = toLocal(c.startsAt!);
    final repeat = c.recurrence == 'once'
        ? ''
        : ' (${recurrenceLabel(c.recurrence)})';
    return '«${c.title}» ${two(t.hour)}:${two(t.minute)}$repeat';
  }

  final names = clashes.take(2).map(one).join(' و');
  return '⚠️ في نفس الوقت تقريباً عندك $names — '
      'تقدر تحفظ عادي أو تغيّر الوقت.';
}
