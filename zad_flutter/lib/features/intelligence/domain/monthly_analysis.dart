/// The numbers behind the monthly report PDF, computed on the phone from the
/// transactions themselves — never from the model. The AI report adds the
/// words (summary, insights, advice); every amount, count, share and cap in
/// the PDF comes from here, so nothing on the page is an invented figure.
///
/// ⚠️ The keyword lists below are matching data, not UI text: they are
/// matched against what users type and what `zad_transactions.category`
/// stores. Never translate them (CLAUDE.md, i18n rule).
library;

import 'dart:math' as math;

import 'package:zad/core/money/money.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// The four household groups of section 1, in the order the PDF shows them.
enum FamilyGroup {
  /// Groceries, bills, rent, cleaning, upkeep.
  house('مصاريف البيت', <String>[
    'بقالة', 'البقالة', 'بقاله', 'سوبرماركت', 'سوبر ماركت', 'هايبر', //
    'تموين', 'خضار', 'فاكهة', 'فواكه', 'لحوم', 'لحمة', 'فراخ', 'خبز',
    'عيش', 'منظفات', 'فواتير', 'الفواتير', 'كهرب', 'مياه', 'غاز', 'إيجار',
    'ايجار', 'صيانة', 'سباك', 'كهربائي', 'انترنت', 'إنترنت', 'نت',
    'منزل', 'البيت', 'بيت', 'أدوات منزلية', 'مطبخ', 'grocery',
    'supermarket', 'carrefour', 'panda', 'lulu',
  ]),

  /// School, nursery, diapers, formula, toys, pocket money.
  kids('مستلزمات الأطفال', <String>[
    'أطفال', 'اطفال', 'الأطفال', 'طفل', 'الطفل', 'ولاد', 'العيال', //
    'مدرسة', 'مدرسه', 'مدارس', 'المدرسة', 'التعليم', 'تعليم', 'حضانة',
    'دروس', 'درس خصوصي', 'كتب', 'أدوات مدرسية', 'زي مدرسي', 'يونيفورم',
    'حفاض', 'حفاضات', 'بامبرز', 'pampers', 'لبن أطفال', 'حليب أطفال',
    'سيريلاك', 'ألعاب', 'لعب', 'لعبة', 'مصروف', 'kids', 'school', 'toys',
  ]),

  /// Pharmacy, medicine, doctors.
  pharmacy('الأدوية والصيدلية', <String>[
    'صيدلية', 'صيدليه', 'الصيدلية', 'دواء', 'الدواء', 'أدوية', 'ادوية', //
    'علاج', 'الرعاية الصحية', 'صحة', 'مستشفى', 'عيادة', 'طبيب', 'دكتور',
    'تحاليل', 'أشعة', 'النهدي', 'nahdi', 'pharmacy', 'hospital', 'clinic',
  ]),

  /// Outings, restaurants, clubs, trips.
  activities('الأنشطة والخروجات العائلية', <String>[
    'ترفيه', 'خروج', 'خروجة', 'فسحة', 'نزهة', 'رحلة', 'مصيف', 'سفر', //
    'نادي', 'النادي', 'سينما', 'ملاهي', 'حديقة', 'مطعم', 'مطاعم', 'المطاعم',
    'كافيه', 'أكل برا', 'الأكل برا', 'وجبات', 'توصيل طعام', 'طلبات',
    'هدايا', 'هدية', 'عيد ميلاد', 'restaurant', 'cafe', 'cinema',
  ]);

  new(this.label, this.keywords);

  /// The card's title.
  final String label;

  /// Matched, case-insensitively, inside the category, title and merchant.
  final List<String> keywords;

  /// The group a transaction belongs to, or null. Checked in the order kids,
  /// pharmacy, activities, house — «مدرسة» is a child's cost before it is
  /// a household one, and a pharmacy bill is medicine before it is a bill.
  static FamilyGroup? of(ZadTransaction t) {
    final text = _haystack(t);
    for (final g in const <FamilyGroup>[kids, pharmacy, activities, house]) {
      if (g.keywords.any((k) => text.contains(k.toLowerCase()))) return g;
    }
    return null;
  }
}

/// Transport, for the costly-trips alert. Matching data — see the header.
const List<String> _transportKeywords = <String>[
  'مواصلات', 'المواصلات', 'أوبر', 'اوبر', 'كريم', 'تاكسي', 'تكسي', //
  'بنزين', 'وقود', 'بترول', 'محطة وقود', 'باص', 'اتوبيس', 'أتوبيس', 'قطار',
  'مترو', 'ميكروباص', 'توك توك', 'طيران', 'تذكرة طيران', 'جراج', 'باركنج',
  'موقف', 'uber', 'careem', 'taxi', 'indrive', 'didi', 'bolt', 'fuel',
  'parking',
];

/// Categories a cap must not cut: medicine, bills, rent, instalments,
/// school fees. Zad never suggests trimming a fixed obligation.
const List<String> _essentialKeywords = <String>[
  'صيدلية', 'دواء', 'أدوية', 'علاج', 'الرعاية الصحية', 'مستشفى', 'طبيب', //
  'فواتير', 'الفواتير', 'كهرب', 'مياه', 'غاز', 'إيجار', 'ايجار', 'قسط',
  'أقساط', 'الأقساط', 'التعليم', 'مدرسة', 'مدارس', 'حضانة', 'تأمين',
];

String _haystack(ZadTransaction t) => <String?>[
  t.category,
  t.title,
  t.merchantName,
].whereType<String>().join(' ').toLowerCase();

bool _matches(String text, List<String> keywords) =>
    keywords.any((k) => text.contains(k.toLowerCase()));

/// The category a transaction is filed under, `أخرى` when it has none.
String categoryOf(ZadTransaction t) {
  final c = t.category?.trim() ?? '';
  return c.isEmpty ? 'أخرى' : c;
}

/// One card of section 1.
class GroupSpend {
  /// A group's totals.
  const new({
    required this.group,
    required this.total,
    required this.count,
    required this.share,
    required this.topItems,
  });

  /// Which group.
  final FamilyGroup group;

  /// What it cost this cycle.
  final double total;

  /// How many purchases.
  final int count;

  /// [total] over the cycle's whole spend, 0..1.
  final double share;

  /// Its three largest items by title, with what each cost in total.
  final List<(String, double)> topItems;
}

/// The same thing bought more than once inside seven days.
class DuplicatePurchase {
  /// A repeated purchase.
  const new({
    required this.title,
    required this.count,
    required this.total,
    required this.category,
  });

  /// What was bought, as the first of the repeats spelled it.
  final String title;

  /// Times it was bought inside the busiest seven-day window.
  final int count;

  /// What those purchases cost together.
  final double total;

  /// Where they were filed.
  final String category;
}

/// Section 2's transport card.
class TransportAlert {
  /// The cycle's transport.
  const new({
    required this.total,
    required this.trips,
    required this.share,
    required this.costlyTrips,
    required this.median,
  });

  /// Spent on transport.
  final double total;

  /// Number of transport purchases.
  final int trips;

  /// [total] over the cycle's spend, 0..1.
  final double share;

  /// Trips over 1.5× the median trip, largest first, at most three.
  final List<(String, double)> costlyTrips;

  /// The median trip.
  final double median;

  /// Worth warning about: a sixth or more of the month, or outlier trips.
  bool get isCostly => share >= 0.15 || costlyTrips.isNotEmpty;
}

/// Section 2's small-purchases card.
class SmallPurchases {
  /// Small purchases that add up.
  const new({
    required this.threshold,
    required this.count,
    required this.total,
    required this.share,
  });

  /// "Small" means at most this — half the cycle's median purchase.
  final double threshold;

  /// How many.
  final int count;

  /// What they add up to.
  final double total;

  /// [total] over the cycle's spend, 0..1.
  final double share;
}

/// One row of the comparison table and its cap for next month.
class CategoryLine {
  /// A category's month-on-month line.
  const new({
    required this.category,
    required this.current,
    required this.previous,
    required this.cap,
    required this.essential,
  });

  /// The category name, as stored.
  final String category;

  /// This cycle's spend.
  final double current;

  /// The previous cycle's spend (0 when nothing was recorded).
  final double previous;

  /// The suggested ceiling for next month.
  final double cap;

  /// Medicine, bills, rent, instalments, school: never cut.
  final bool essential;

  /// Relative change against the previous cycle, or null with no base.
  double? get change => previous <= 0 ? null : (current - previous) / previous;

  /// What keeping to [cap] saves against this month.
  double get saving => math.max<double>(0, current - cap).asMoney;
}

/// Everything section 1–3 of the PDF shows.
class MonthlyAnalysis {
  /// The computed month.
  const new({
    required this.start,
    required this.end,
    required this.spent,
    required this.income,
    required this.budget,
    required this.count,
    required this.family,
    required this.otherSpend,
    required this.duplicates,
    required this.transport,
    required this.small,
    required this.lines,
  });

  /// The cycle, `[start, end)`.
  final DateTime start;

  /// See [start].
  final DateTime end;

  /// Expenses in the cycle.
  final double spent;

  /// Income in the cycle.
  final double income;

  /// The cycle's budget, when one is set.
  final double? budget;

  /// Expense count.
  final int count;

  /// The four groups, always all four, in [FamilyGroup] order.
  final List<GroupSpend> family;

  /// Spend outside the four groups.
  final double otherSpend;

  /// Repeats inside a week, largest total first, at most five.
  final List<DuplicatePurchase> duplicates;

  /// Null when no transport was recorded.
  final TransportAlert? transport;

  /// Null when fewer than five small purchases.
  final SmallPurchases? small;

  /// Largest categories first, at most eight.
  final List<CategoryLine> lines;

  /// [spent] over [budget], or null without a budget.
  double? get usage => (budget ?? 0) <= 0 ? null : spent / budget!;

  /// What keeping every cap saves.
  double get savings => lines.fold<double>(0, (s, l) => s + l.saving).asMoney;

  /// Whether section 2 has anything to warn about.
  bool get hasHabitAlerts =>
      duplicates.isNotEmpty || (transport?.isCostly ?? false) || small != null;
}

/// The window before `[start, end)`. A monthly cycle (28–31 days) steps back
/// one calendar month — September 1 → August 1, so rent paid on the 1st lands
/// in the comparison; any other length steps back by its own duration.
(DateTime, DateTime) previousWindow(DateTime start, DateTime end) {
  final days = end.difference(start).inDays;
  if (days < 28 || days > 31) {
    return (start.subtract(end.difference(start)), start);
  }
  final y = start.month == 1 ? start.year - 1 : start.year;
  final m = start.month == 1 ? 12 : start.month - 1;
  final lastDay = DateTime.utc(y, m + 1, 0).day;
  final d = math.min(start.day, lastDay);
  final prev = start.isUtc
      ? DateTime.utc(y, m, d, start.hour, start.minute, start.second)
      : DateTime(y, m, d, start.hour, start.minute, start.second);
  return (prev, start);
}

/// Computes the analysis for `[start, end)` from [transactions] (all of
/// them — the previous cycle is read from the same list).
MonthlyAnalysis analyzeMonth({
  required List<ZadTransaction> transactions,
  required DateTime start,
  required DateTime end,
  double? budget,
}) {
  bool inRange(ZadTransaction t, DateTime from, DateTime to) =>
      !t.createdAt.isBefore(from) && t.createdAt.isBefore(to);

  final expenses =
      transactions
          .where((t) => t.kind == TxnKind.expense && inRange(t, start, end))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final income = transactions
      .where((t) => t.kind == TxnKind.income && inRange(t, start, end))
      .fold<double>(0, (s, t) => s + t.amount);
  final spent = expenses.fold<double>(0, (s, t) => s + t.amount).asMoney;
  double share(double v) => spent <= 0 ? 0 : v / spent;

  // ── 1. Family groups.
  final byGroup = <FamilyGroup, List<ZadTransaction>>{
    for (final g in FamilyGroup.values) g: <ZadTransaction>[],
  };
  var other = 0.0;
  for (final t in expenses) {
    final g = FamilyGroup.of(t);
    if (g == null) {
      other += t.amount;
    } else {
      byGroup[g]!.add(t);
    }
  }
  final family = <GroupSpend>[
    for (final g in FamilyGroup.values)
      () {
        final list = byGroup[g]!;
        final total = list.fold<double>(0, (s, t) => s + t.amount).asMoney;
        final items = <String, double>{};
        for (final t in list) {
          final k = t.title.trim().isEmpty ? categoryOf(t) : t.title.trim();
          items[k] = (items[k] ?? 0) + t.amount;
        }
        final top = items.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return GroupSpend(
          group: g,
          total: total,
          count: list.length,
          share: share(total),
          topItems: <(String, double)>[
            for (final e in top.take(3)) (e.key, e.value.asMoney),
          ],
        );
      }(),
  ];

  // ── 2a. The same title bought twice or more inside seven days. Transport
  // and small purchases have cards of their own below, so a second taxi or a
  // daily coffee is not reported here as well.
  final smallThreshold = expenses.length >= 5
      ? (_median(expenses.map((t) => t.amount)) / 2).asMoney
      : 0.0;
  final byTitle = <String, List<ZadTransaction>>{};
  for (final t in expenses) {
    if (_matches(_haystack(t), _transportKeywords)) continue;
    if (t.amount <= smallThreshold) continue;
    final key = _normalize(t.title);
    if (key.isEmpty) continue;
    (byTitle[key] ??= <ZadTransaction>[]).add(t);
  }
  final duplicates = <DuplicatePurchase>[];
  for (final list in byTitle.values) {
    if (list.length < 2) continue;
    var best = <ZadTransaction>[];
    for (var i = 0; i < list.length; i++) {
      final window = <ZadTransaction>[
        for (var j = i; j < list.length; j++)
          if (list[j].createdAt.difference(list[i].createdAt).inDays < 7)
            list[j],
      ];
      if (window.length > best.length) best = window;
    }
    if (best.length < 2) continue;
    duplicates.add(
      DuplicatePurchase(
        title: best.first.title.trim(),
        count: best.length,
        total: best.fold<double>(0, (s, t) => s + t.amount).asMoney,
        category: categoryOf(best.first),
      ),
    );
  }
  duplicates.sort((a, b) => b.total.compareTo(a.total));

  // ── 2b. Transport.
  final trips = expenses
      .where((t) => _matches(_haystack(t), _transportKeywords))
      .toList();
  TransportAlert? transport;
  if (trips.isNotEmpty) {
    final total = trips.fold<double>(0, (s, t) => s + t.amount).asMoney;
    final median = _median(trips.map((t) => t.amount));
    final costly = trips.length < 3
        ? <ZadTransaction>[]
        : (trips.where((t) => t.amount > median * 1.5).toList()
            ..sort((a, b) => b.amount.compareTo(a.amount)));
    transport = TransportAlert(
      total: total,
      trips: trips.length,
      share: share(total),
      median: median.asMoney,
      costlyTrips: <(String, double)>[
        for (final t in costly.take(3)) (t.title.trim(), t.amount),
      ],
    );
  }

  // ── 2c. Small purchases that add up.
  SmallPurchases? small;
  if (expenses.length >= 5) {
    final threshold = smallThreshold;
    final smalls = expenses.where((t) => t.amount <= threshold).toList();
    if (smalls.length >= 5) {
      final total = smalls.fold<double>(0, (s, t) => s + t.amount).asMoney;
      small = SmallPurchases(
        threshold: threshold,
        count: smalls.length,
        total: total,
        share: share(total),
      );
    }
  }

  // ── 3. Month-on-month lines and caps.
  final (prevStart, prevEnd) = previousWindow(start, end);
  final current = <String, double>{};
  for (final t in expenses) {
    current[categoryOf(t)] = (current[categoryOf(t)] ?? 0) + t.amount;
  }
  final previous = <String, double>{};
  for (final t in transactions.where(
    (t) => t.kind == TxnKind.expense && inRange(t, prevStart, prevEnd),
  )) {
    previous[categoryOf(t)] = (previous[categoryOf(t)] ?? 0) + t.amount;
  }
  final flagged = <String>{
    for (final d in duplicates) d.category,
    if (transport?.isCostly ?? false)
      for (final t in trips) categoryOf(t),
  };
  final ordered = current.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final lines = <CategoryLine>[
    for (final e in ordered.take(8))
      () {
        final essential = _matches(e.key.toLowerCase(), _essentialKeywords);
        return CategoryLine(
          category: e.key,
          current: e.value.asMoney,
          previous: (previous[e.key] ?? 0).asMoney,
          essential: essential,
          cap: essential
              ? e.value.asMoney
              : suggestedCap(
                  current: e.value,
                  previous: previous[e.key] ?? 0,
                  flagged: flagged.contains(e.key),
                ),
        );
      }(),
  ];

  return MonthlyAnalysis(
    start: start,
    end: end,
    spent: spent,
    income: income.asMoney,
    budget: budget,
    count: expenses.length,
    family: family,
    otherSpend: other.asMoney,
    duplicates: duplicates.take(5).toList(),
    transport: transport,
    small: small,
    lines: lines,
  );
}

/// Next month's ceiling for a category that is not essential:
/// - 10% under this month by default;
/// - back to last month's level when it grew by more than a fifth, but never
///   a cut deeper than 20% in one month;
/// - 15% under when section 2 flagged a habit in it;
/// rounded down to a multiple of 5, never above this month.
double suggestedCap({
  required double current,
  required double previous,
  required bool flagged,
}) {
  if (current <= 0) return 0;
  var cap = current * 0.9;
  if (previous > 0 && current > previous * 1.2) {
    cap = math.max(previous, current * 0.8);
  }
  if (flagged) cap = math.min(cap, current * 0.85);
  final rounded = (cap / 5).floor() * 5.0;
  return (rounded <= 0 ? current : math.min(rounded, current)).asMoney;
}

/// Practical steps built from the analysis — the non-AI half of section 3.
List<String> savingSteps(MonthlyAnalysis a, String Function(double) money) {
  final steps = <String>[];
  for (final d in a.duplicates.take(2)) {
    steps.add(
      '«${d.title}» اتشرى ${timesLabel(d.count)} في أسبوع واحد '
      'بـ ${money(d.total)} — '
      'اكتب قائمة المشتريات قبل ما تنزل واشتري مرة واحدة في الأسبوع.',
    );
  }
  final t = a.transport;
  if (t != null && t.isCostly) {
    steps.add(
      'المواصلات أخدت ${_percent(t.share)} من مصروف الشهر '
      '(${t.trips} مشوار، متوسط ${money(t.median)}) — جمّع المشاوير في '
      'يوم واحد وقارن سعر الرحلة قبل ما تطلبها.',
    );
  }
  final s = a.small;
  if (s != null) {
    steps.add(
      '${s.count} مشترى صغير (كل واحد ${money(s.threshold)} أو أقل) وصلوا '
      '${money(s.total)} — حدد مبلغ أسبوعي ثابت للحاجات الصغيرة.',
    );
  }
  if (a.savings > 0) {
    steps.add(
      'لو التزمت بالسقوف المقترحة في الجدول هتوفر حوالي ${money(a.savings)} '
      'الشهر الجاي.',
    );
  }
  return steps;
}

/// `مرتين` for two, `3 مرات` from three on.
String timesLabel(int n) => n == 2 ? 'مرتين' : '$n مرات';

String _percent(double v) => '${(v * 100).round()}%';

String _normalize(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[\d٠-٩.,]+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

double _median(Iterable<double> values) {
  final v = values.toList()..sort();
  if (v.isEmpty) return 0;
  final m = v.length ~/ 2;
  return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
}
