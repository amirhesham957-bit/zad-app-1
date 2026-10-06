/// ميزانية المواعيد (ZAD_LIVING_BRAIN.md الشريحة ٤٠): يوم فيه مشوار برّه
/// البيت (دكتور، سفر، خروجة) بياخد وزن أكبر من «المصروف الآمن في اليوم»،
/// وباقي أيام الأسبوع بتشيل الفرق. **إعادة توزيع بس** — مجموع الأيام = نفس
/// المتاح، ومفيش رقم مصروف مخترع للمشوار. نفس القاعدة في العقل
/// (`zad-brain/eventDayBudget.ts`) عشان الشات مايقولش رقم تاني.
library;

/// A trip counts double.
const double kTravelWeight = 2;

/// Any other outing, and anything medical, counts one and a half.
const double kOutingWeight = 1.5;

/// How far ahead the rebalancing reaches.
const int kEventHorizonDays = 7;

final RegExp _travel = RegExp('سفر|مسافر|رحل[هة]|مصيف|طيار[هة]|المطار');
final RegExp _outing = RegExp(
  'دكتور|عياد[هة]|مستشفي|مستشفى|تحاليل|[اأ]شع[هة]|خروج[هة]|فسح[هة]|سينما|'
  'مطعم|عزوم[هة]|فرح|عيد ميلاد|ملاهي|مول|النادي',
);

/// An appointment as the rule reads it.
typedef OutingAppointment = ({
  String title,
  String kind,
  DateTime startsAt,
  String recurrence,
  String status,
});

/// 2 for a trip, 1.5 for an outing, 1 otherwise — and 1 for anything
/// recurring or not upcoming: the weekly gym is part of the ordinary days.
double eventWeight(OutingAppointment a) {
  if (a.recurrence != 'once' || a.status != 'upcoming') return 1;
  if (_travel.hasMatch(a.title)) return kTravelWeight;
  if (a.kind == 'medical' || _outing.hasMatch(a.title)) return kOutingWeight;
  return 1;
}

/// Today's share after the rebalancing.
typedef EventDayBudget = ({
  double today,
  double base,
  String eventTitle,
  int eventInDays,
});

/// Null when there is no outing within the week, or nothing to spread.
/// [toLocal] gives the account's civil time; [now] is an instant.
EventDayBudget? eventDayBudget({
  required double spendable,
  required int daysLeft,
  required List<OutingAppointment> appointments,
  required DateTime now,
  required DateTime Function(DateTime utc) toLocal,
}) {
  if (spendable <= 0) return null;
  final days = daysLeft < 1 ? 1 : daysLeft;
  final horizon = days < kEventHorizonDays ? days : kEventHorizonDays;
  final today = toLocal(now);
  final first = DateTime.utc(today.year, today.month, today.day);
  final weights = List<double>.filled(horizon, 1);
  final titles = List<String?>.filled(horizon, null);
  for (final a in appointments) {
    final w = eventWeight(a);
    if (w <= 1) continue;
    final l = toLocal(a.startsAt);
    final i = DateTime.utc(l.year, l.month, l.day).difference(first).inDays;
    if (i < 0 || i >= horizon || w <= weights[i]) continue;
    weights[i] = w;
    titles[i] = a.title.trim().isEmpty ? 'مشوار' : a.title.trim();
  }
  final at = titles.indexWhere((t) => t != null);
  if (at < 0) return null;
  final base = spendable / days;
  final sum = weights.reduce((a, b) => a + b);
  double round(double v) => (v * 100).roundToDouble() / 100;
  return (
    today: round(base * horizon * weights[0] / sum),
    base: round(base),
    eventTitle: titles[at]!,
    eventInDays: at,
  );
}

const List<String> _weekdays = <String>[
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
  'السبت',
  'الحد',
];

/// The caption under the figure: why today is more, or why it is a little
/// less. [weekday] is the event day's `DateTime.weekday`.
String eventDayCaption(EventDayBudget e, {required int weekday}) {
  if (e.eventInDays == 0) return 'زوّدناه عشان «${e.eventTitle}» النهارده';
  final when = e.eventInDays == 1 ? 'بكرة' : 'يوم ${_weekdays[weekday - 1]}';
  return 'شايلين حاجة لـ«${e.eventTitle}» $when';
}
