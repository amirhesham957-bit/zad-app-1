/// A prescription or a school timetable read off a photo
/// (`analyze_document_image`, docs/agent/ZAD_LIVING_BRAIN.md slice 21).
///
/// The server only transcribes; it never guesses a medicine or a dose. A line
/// it could not read with confidence comes back `legible: false`, and the
/// review screen leaves it unticked.
library;

import 'package:flutter/foundation.dart';

/// Which document.
enum DocumentKind {
  /// A doctor's prescription.
  prescription('prescription'),

  /// A school class timetable.
  timetable('timetable');

  new(this.wire);

  /// The value the server takes.
  final String wire;
}

/// One medicine on a prescription.
@immutable
class PrescriptionLine {
  /// Creates a line.
  const new({
    required this.name,
    this.strength,
    this.form,
    this.instructions,
    this.timesPerDay,
    this.durationDays,
    this.asNeeded = false,
    this.legible = true,
    this.suggestedTimes,
    this.courseDoses,
  });

  /// Reads a line from the server.
  factory fromJson(Map<String, dynamic> j) => PrescriptionLine(
    name: (j['name'] as String? ?? '').trim(),
    strength: j['strength'] as String?,
    form: j['form'] as String?,
    instructions: j['instructions'] as String?,
    timesPerDay: (j['times_per_day'] as num?)?.toInt(),
    durationDays: (j['duration_days'] as num?)?.toInt(),
    asNeeded: j['as_needed'] == true,
    legible: j['legible'] != false,
    suggestedTimes: j['suggested_times'] as String?,
    courseDoses: (j['course_doses'] as num?)?.toInt(),
  );

  /// As written.
  final String name;

  /// '500 mg', '5 ml'.
  final String? strength;

  /// قرص، شراب…
  final String? form;

  /// The directions exactly as written.
  final String? instructions;

  /// Only when the paper says it.
  final int? timesPerDay;

  /// Only when the paper says it.
  final int? durationDays;

  /// «عند اللزوم».
  final bool asNeeded;

  /// False when the handwriting could not be read with confidence.
  final bool legible;

  /// Times derived from [timesPerDay] on the server ("08:00,14:00,20:00").
  final String? suggestedTimes;

  /// Doses in the whole course when both frequency and duration are written.
  final int? courseDoses;
}

/// A prescription.
@immutable
class ScannedPrescription {
  /// Creates a prescription.
  const new({
    required this.medicines,
    this.patientName,
    this.doctor,
    this.date,
  });

  /// Reads the server's `document`.
  factory fromJson(Map<String, dynamic> j) => ScannedPrescription(
    patientName: j['patient_name'] as String?,
    doctor: j['doctor'] as String?,
    date: j['date'] as String?,
    medicines: <PrescriptionLine>[
      for (final m in (j['medicines'] as List<dynamic>? ?? const <dynamic>[]))
        if (m is Map) PrescriptionLine.fromJson(Map<String, dynamic>.from(m)),
    ].where((m) => m.name.isNotEmpty).toList(),
  );

  /// Printed on it, if at all.
  final String? patientName;

  /// Printed on it, if at all.
  final String? doctor;

  /// YYYY-MM-DD, if written.
  final String? date;

  /// The lines.
  final List<PrescriptionLine> medicines;
}

/// One class.
@immutable
class TimetablePeriod {
  /// Creates a period.
  const new({required this.order, required this.subject, this.start, this.end});

  /// Reads a period.
  factory fromJson(Map<String, dynamic> j) => TimetablePeriod(
    order: (j['order'] as num?)?.toInt() ?? 0,
    subject: (j['subject'] as String? ?? '').trim(),
    start: j['start'] as String?,
    end: j['end'] as String?,
  );

  /// 1 = first.
  final int order;

  /// As written.
  final String subject;

  /// HH:MM when printed.
  final String? start;

  /// HH:MM when printed.
  final String? end;

  /// For the save.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'order': order,
    'subject': subject,
    'start': ?start,
    'end': ?end,
  };
}

/// One school day.
@immutable
class TimetableDay {
  /// Creates a day.
  const new({required this.weekday, required this.periods});

  /// Reads a day.
  factory fromJson(Map<String, dynamic> j) => TimetableDay(
    weekday: (j['weekday'] as num?)?.toInt() ?? -1,
    periods: <TimetablePeriod>[
      for (final p in (j['periods'] as List<dynamic>? ?? const <dynamic>[]))
        if (p is Map) TimetablePeriod.fromJson(Map<String, dynamic>.from(p)),
    ].where((p) => p.subject.isNotEmpty).toList(),
  );

  /// 0 = الأحد … 6 = السبت.
  final int weekday;

  /// In order.
  final List<TimetablePeriod> periods;

  /// For the save.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'weekday': weekday,
    'periods': <Map<String, dynamic>>[for (final p in periods) p.toJson()],
  };
}

/// A school timetable.
@immutable
class ScannedTimetable {
  /// Creates a timetable.
  const new({required this.days, this.studentName, this.className});

  /// Reads the server's `document`.
  factory fromJson(Map<String, dynamic> j) => ScannedTimetable(
    studentName: j['student_name'] as String?,
    className: j['class_name'] as String?,
    days:
        <TimetableDay>[
              for (final d
                  in (j['days'] as List<dynamic>? ?? const <dynamic>[]))
                if (d is Map)
                  TimetableDay.fromJson(Map<String, dynamic>.from(d)),
            ]
            .where(
              (d) => d.weekday >= 0 && d.weekday <= 6 && d.periods.isNotEmpty,
            )
            .toList(),
  );

  /// Printed on it, if at all.
  final String? studentName;

  /// Printed on it, if at all.
  final String? className;

  /// The school days.
  final List<TimetableDay> days;
}

/// Arabic day names, 0 = الأحد. Display text.
const List<String> kWeekdayNames = <String>[
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];
