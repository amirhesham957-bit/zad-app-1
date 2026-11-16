/// The pharmacy's rules and stored values, apart from any widget: the
/// categories and units (stored and matched, so Arabic), the dose-time
/// helpers, the monthly cost, the dosage-note cleaner and the one sentence
/// the world's header says about the next dose.
library;

import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/dose_time.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// [text] trimmed, or null when nothing is left.
String? blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

/// A money figure without trailing zeros.
String pharmacyMoney(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Kotlin's categories and units — stored values, kept Arabic.
const List<String> kMedicineCategories = <String>[
  'عام',
  'مسكن',
  'مضاد حيوي',
  'فيتامين',
  'مزمن',
];

/// The units a medicine is counted in. Stored and matched, so Arabic.
///
/// The same names `zad_pharmacy_unit` stores on the server (migration
/// `20261001220000`): no «حبة» beside «قرص» (one kind, two names), and a
/// cream or ointment is «دهان», whose doses never take from the count.
const List<String> kMedicineUnits = <String>[
  'قرص',
  'كبسولة',
  'مل',
  'بخاخ',
  'نقطة',
  'دهان',
  'كيس',
  'أمبول',
  'علبة',
];

/// Kotlin's `suggestDoseTimes`: the doses spread over 08:00–22:00.
String suggestDoseTimes(int count) {
  if (count <= 0) return '';
  if (count == 1) return '09:00';
  const start = 8 * 60;
  const end = 22 * 60;
  final step = (end - start) ~/ (count - 1);
  String two(int n) => n.toString().padLeft(2, '0');
  return <String>[
    for (var i = 0; i < count; i++)
      '${two((start + step * i) ~/ 60)}:${two((start + step * i) % 60)}',
  ].join(', ');
}

/// Kotlin's monthly cost: what the pharmacy took from the budget this
/// period, or the boxes' prices added up, whichever is more.
double pharmacyMonthlyCost(
  Iterable<Medicine> medicines,
  Iterable<ZadTransaction> periodRows,
) {
  final boxes = _boxes(medicines);
  final spent = _healthSpending(periodRows);
  return spent > boxes ? spent : boxes;
}

/// What [pharmacyMonthlyCost] is showing. «التكلفة الشهرية» read as the
/// medicines' cost, while the figure was the period's health spending —
/// clinic visits included — or the boxes' prices (2026-10-10: 1,356.5 over
/// three medicines priced at zero).
String pharmacyCostLabel(
  Iterable<Medicine> medicines,
  Iterable<ZadTransaction> periodRows,
) => _healthSpending(periodRows) > _boxes(medicines)
    ? 'صرف الصحة الشهر ده'
    : 'أسعار علب الأدوية';

double _boxes(Iterable<Medicine> medicines) =>
    medicines.fold<double>(0, (s, m) => s + m.price);

double _healthSpending(Iterable<ZadTransaction> periodRows) {
  var spent = 0.0;
  for (final t in periodRows) {
    if (t.kind != TxnKind.expense) continue;
    final c = t.category;
    if (c == 'الرعاية الصحية' ||
        c == 'صيدلية' ||
        c == 'أدوية' ||
        t.sourceType == 'pharmacy') {
      spent += t.amount;
    }
  }
  return spent;
}

/// A box reading's suggested times as the form keeps them: only what the
/// server's `dose_times` regex accepts, padded, once each, in order.
List<String> scannedDoseTimes(String? raw) {
  final times = <DoseTime>[
    for (final part in (raw ?? '').split(',')) ?DoseTime.parse(part),
  ]..sort();
  return <String>{for (final t in times) t.wireName}.toList();
}

/// The four quick choices, shared by the add form and the times sheet.
const List<(String, String)> kDoseTimePresets = <(String, String)>[
  ('08:00', 'صباحاً'),
  ('14:00', 'ظهراً'),
  ('20:00', 'مساءً'),
  ('23:00', 'قبل النوم'),
];

/// Kotlin's `PharmacyDoseText` frequency patterns — **match data**, compared
/// against the customer's and the model's words (CLAUDE.md i18n rule).
final List<RegExp> _frequencyPatterns = <RegExp>[
  RegExp(r'كل\s*[٠-٩\d]*\s*(ساعات|ساعة|أيام|يومين|يوم|أسابيع|أسبوع)'),
  RegExp(r'[٠-٩\d]+\s*مرا?ت\s*(يومي(?:ا|اً|ًا)?|في\s*اليوم|بالي(?:و|ـو)م)?'),
  RegExp(
    r'(مرة\s*واحدة|مرتين|ثلاث\s*مرات|أربع\s*مرات)\s*(يومي(?:ا|اً|ًا)?|في\s*اليوم)?',
  ),
  RegExp(r'every\s*\d+\s*(hours?|hrs?|days?)', caseSensitive: false),
  RegExp(r'\d+\s*times?\s*(a|per)\s*day', caseSensitive: false),
  RegExp(
    r'(once|twice|three\s*times)\s*(a\s*day|per\s*day|daily)',
    caseSensitive: false,
  ),
];

/// Kotlin's `PharmacyDoseText.sanitizeDosageNote`: the note without any
/// frequency written into it, or null when only the frequency was there.
String? sanitizeDosageNote(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  var stripped = value;
  for (final p in _frequencyPatterns) {
    stripped = stripped.replaceAll(p, ' ');
  }
  final cleaned = stripped
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[،,\-–—./ ]+|[،,\-–—./ ]+$'), '')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// «٩ الصبح» / «٢ الضهر» / «٩ بالليل» — a dose's time the way it is said.
String doseClockWords(DoseSlot slot, String zone) {
  final local = tz.TZDateTime.from(
    slot.scheduledAt.toUtc(),
    tz.getLocation(zone),
  );
  final h = local.hour;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final period = switch (h) {
    >= 4 && < 12 => 'الصبح',
    >= 12 && < 16 => 'الضهر',
    >= 16 && < 19 => 'العصر',
    _ => 'بالليل',
  };
  final minutes = local.minute == 0
      ? ''
      : ':${local.minute.toString().padLeft(2, '0')}';
  return '$h12$minutes $period';
}

/// The "HH:mm" of a slot in the account's zone.
String doseClock(DoseSlot slot, String zone) {
  final local = tz.TZDateTime.from(
    slot.scheduledAt.toUtc(),
    tz.getLocation(zone),
  );
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// How the day's doses stand, for the header line.
enum DayDoseState {
  /// Nothing has a schedule.
  unscheduled,

  /// A dose is due right now.
  due,

  /// Doses are still to come.
  upcoming,

  /// A dose was missed and nothing else is waiting.
  missed,

  /// Every dose that has come up is taken.
  done,
}

/// The header's one line, from the real slots, and the state behind it.
({String line, DayDoseState state}) nextDoseLine(
  List<DoseSlot> today,
  DateTime now,
  String zone,
) {
  if (today.isEmpty) {
    return (line: 'مفيش جرعات النهارده', state: DayDoseState.unscheduled);
  }
  DoseSlot? first(DoseState s) {
    for (final slot in today) {
      if (slot.stateAt(now) == s) return slot;
    }
    return null;
  }

  final due = first(DoseState.due);
  if (due != null) {
    return (
      line: 'جرعة ${due.medicine.name} وقتها دلوقتي',
      state: DayDoseState.due,
    );
  }
  final next = first(DoseState.upcoming);
  if (next != null) {
    return (
      line: 'الجرعة الجاية ${doseClockWords(next, zone)}',
      state: DayDoseState.upcoming,
    );
  }
  final missed = first(DoseState.missed);
  if (missed != null) {
    return (
      line: 'فاتتك جرعة ${missed.medicine.name}',
      state: DayDoseState.missed,
    );
  }
  return (line: 'خلصت جرعات النهارده', state: DayDoseState.done);
}
