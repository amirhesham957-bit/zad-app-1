/// Turning a schedule into moments, the same way the server does.
///
/// This is the file that has to agree with `zad_enqueue_missed_doses`
/// character for character, because the two answer the same question from
/// different sides: the cron decides when to nudge, and this decides what the
/// screen says is due. If they disagree the app shows a dose as taken care of
/// while the customer is being asked about it, or the other way round.
///
/// The SQL, for reference:
///
/// ```sql
/// cross join lateral (values (0), (1)) as d(days_back)
/// ...
/// (((now() at time zone tz)::date - d.days_back) + t.raw::time)
///   at time zone tz
/// ```
///
/// Two things carry across. The date is **today in the account's market
/// zone**, not UTC and not the device's zone. And yesterday is included —
/// `values (0), (1)` — because a slot at `00:00` belongs to a day boundary and
/// a three-hour grace window reaches back across it.
library;

import 'package:timezone/timezone.dart' as tz;
import 'package:zad/features/pharmacy/domain/dose_time.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// One dose that was, or will be, due.
class DoseSlot {
  /// Creates a slot.
  const new({
    required this.medicine,
    required this.time,
    required this.scheduledAt,
    this.takenAt,
  });

  /// Which medicine.
  final Medicine medicine;

  /// The civil time it is due at.
  final DoseTime time;

  /// The instant that civil time lands on, in UTC.
  final DateTime scheduledAt;

  /// When it was recorded as taken, if it was.
  final DateTime? takenAt;

  /// Whether this dose has been recorded.
  bool get isTaken => takenAt != null;

  /// Where this slot stands at [now].
  DoseState stateAt(DateTime now) {
    if (isTaken) return DoseState.taken;

    final utcNow = now.toUtc();
    if (scheduledAt.isAfter(utcNow)) return DoseState.upcoming;

    // Past the grace window with nothing recorded. The cron treats the same
    // span as a missed dose worth speaking up about.
    return utcNow.difference(scheduledAt) > takenWindow
        ? DoseState.missed
        : DoseState.due;
  }

  /// A copy carrying a recorded time.
  DoseSlot markTaken(DateTime? at) => DoseSlot(
    medicine: medicine,
    time: time,
    scheduledAt: scheduledAt,
    takenAt: at,
  );

  /// How long after its time a dose still counts as that dose.
  ///
  /// Three hours, and it is the server's number — `zad_enqueue_missed_doses`
  /// treats a record from `scheduled_at - 3 hours` onwards as having answered
  /// the slot. Shortening it here would make the app ask again for a dose the
  /// server considers taken.
  static const Duration takenWindow = Duration(hours: 3);

  /// How long after its time the server waits before it says anything.
  ///
  /// The cron's lower bound: `scheduled_at between now() - 3 hours and now() -
  /// 30 minutes`. Nothing is late until this has passed.
  static const Duration nudgeDelay = Duration(minutes: 30);
}

/// Where a dose stands.
enum DoseState {
  /// Still to come today.
  upcoming,

  /// Due now, or within the grace window.
  due,

  /// The window passed with nothing recorded.
  missed,

  /// Recorded.
  taken,
}

/// Every slot for [medicine] from [daysBack] days ago through [daysForward].
///
/// Returns nothing for a medicine the server would skip — no schedule, an
/// invalid-time flag, or nothing left to take. That is [Medicine.isScheduled],
/// and matching it is what stops the screen promising an alert the cron will
/// never send.
///
/// [now] and [timeZone] are both required and neither is read from the
/// environment. The zone is the account's market zone — `marketTimeZone(
/// country)`, mirroring `zad_market_timezone` — and passing the device's
/// instead is the whole bug this file exists to avoid.
List<DoseSlot> doseSlotsFor(
  Medicine medicine, {
  required DateTime now,
  required String timeZone,
  int daysBack = 1,
  int daysForward = 0,
}) {
  if (!medicine.isScheduled) return const <DoseSlot>[];

  final location = tz.getLocation(timeZone);
  // Today *in that zone*. Reading the calendar date off `now` in UTC would be
  // a different day for anywhere east of Greenwich after midnight, and for
  // anywhere west of it before.
  final local = tz.TZDateTime.from(now.toUtc(), location);

  final slots = <DoseSlot>[];
  for (var offset = -daysBack; offset <= daysForward; offset++) {
    final day = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day + offset,
    );

    for (final time in medicine.doseTimes) {
      slots.add(
        DoseSlot(
          medicine: medicine,
          time: time,
          // Built in the zone, then read as an instant. Constructing a
          // `TZDateTime` this way is what applies the offset — including the
          // day a clock change makes 23 or 25 hours long.
          scheduledAt: tz.TZDateTime(
            location,
            day.year,
            day.month,
            day.day,
            time.hour,
            time.minute,
          ).toUtc(),
        ),
      );
    }
  }

  return slots..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}

/// Marks each slot taken from [records], using the server's own matching rule.
///
/// A record answers a slot when it lands at or after `scheduledAt -
/// takenWindow`, and the earliest such record wins. The window reaching
/// *backwards* is deliberate and is the server's: somebody who takes the
/// eight o'clock tablet at ten to eight has taken it.
List<DoseSlot> applyRecords(List<DoseSlot> slots, List<DateTime> records) {
  if (records.isEmpty) return slots;

  final sorted = records.map((r) => r.toUtc()).toList()..sort();
  final answered = <DateTime>{};

  return <DoseSlot>[
    for (final slot in slots)
      slot.markTaken(_firstUnused(sorted, slot, answered)),
  ];
}

/// The earliest record that answers [slot] and has not already answered
/// another one.
///
/// One record per slot: a single tablet at eight cannot settle both the eight
/// o'clock dose and the four o'clock one, and without this a customer who
/// logged once would see a whole day go quiet.
DateTime? _firstUnused(
  List<DateTime> sorted,
  DoseSlot slot,
  Set<DateTime> answered,
) {
  final earliest = slot.scheduledAt.subtract(DoseSlot.takenWindow);
  final latest = slot.scheduledAt.add(DoseSlot.takenWindow);

  for (final record in sorted) {
    if (record.isBefore(earliest)) continue;
    if (record.isAfter(latest)) break;
    if (answered.contains(record)) continue;
    answered.add(record);
    return record;
  }
  return null;
}
