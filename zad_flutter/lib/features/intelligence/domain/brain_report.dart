/// Kotlin's `ZadCentralBrain.generateReport` and `buildExportText`: the
/// monthly report behind «تصدير التقرير الشهري» — computed on the phone from
/// the rows already here, no model call.
///
/// The numbers follow Kotlin's rules to the letter: spending and income are
/// `txn_kind`-based (an ATM withdrawal is not spending), the calendar month
/// in the account's zone, the health score counts money only (inventory was
/// taken out of it on 2026-09-07), and fixed obligations (rent, instalments,
/// bills) never count as "discretionary". The Arabic strings are Kotlin's.
library;

import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/shared/subscriptions/domain/subscription.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// A category's month.
class CategorySpend {
  /// Creates one.
  const new({
    required this.category,
    required this.spent,
    required this.budget,
  });

  /// The stored category.
  final String category;

  /// Spent this month.
  final double spent;

  /// Its ceiling, 0 when none.
  final double budget;

  /// Percent of the ceiling used.
  int get pctUsed => budget > 0 ? (spent / budget * 100).toInt() : 0;

  /// Over the ceiling.
  bool get isOverBudget => budget > 0 && spent > budget;
}

/// Kotlin's `SpendingPower`.
class SpendingPower {
  /// Creates one.
  const new({
    required this.dailySafeSpend,
    required this.currentDailyAvg,
    required this.daysLeftInMonth,
    required this.powerPct,
    required this.status,
  });

  /// Safe to spend a day; null without a ceiling.
  final double? dailySafeSpend;

  /// Actual daily average.
  final double currentDailyAvg;

  /// Days left, today included.
  final int daysLeftInMonth;

  /// Remaining as a share of the ceiling; null without one.
  final int? powerPct;

  /// قوي / متوازن / ضعيف / خطر / غير محدد.
  final String status;
}

/// Kotlin's `BehaviorProfile`.
class BehaviorProfile {
  /// Creates one.
  const new({
    required this.topSpendingDay,
    required this.weekendSharePct,
    required this.avgTransaction,
    required this.impulsePurchases,
  });

  /// The weekday spent on most.
  final String topSpendingDay;

  /// Friday + Saturday share.
  final int weekendSharePct;

  /// Average expense.
  final double avgTransaction;

  /// Expenses over twice the average in the last 30 days.
  final int impulsePurchases;
}

/// Kotlin's `MonthComparison`.
class MonthComparison {
  /// Creates one.
  const new({
    required this.thisMonthSpent,
    required this.lastMonthSpent,
    required this.deltaPct,
  });

  /// This month so far.
  final double thisMonthSpent;

  /// Last month up to the same day.
  final double lastMonthSpent;

  /// Positive = spending more.
  final int deltaPct;
}

/// Kotlin's `BrainReport`, the parts the export reads.
class BrainReport {
  /// Creates one.
  const new({
    required this.healthScore,
    required this.healthLabel,
    required this.totalSpent,
    required this.totalIncome,
    required this.budget,
    required this.remaining,
    required this.categoryBreakdown,
    required this.topMerchants,
    required this.subscriptionsMonthlyCost,
    required this.insights,
    required this.spendingPower,
    required this.behaviorProfile,
    required this.monthComparison,
    required this.hasEnoughData,
  });

  /// 0–100.
  final int healthScore;

  /// ممتاز / جيد / يحتاج انتباه / خطر.
  final String healthLabel;

  /// Spent this month.
  final double totalSpent;

  /// Income this month.
  final double totalIncome;

  /// The monthly ceiling.
  final double budget;

  /// Null without a ceiling.
  final double? remaining;

  /// Per category, most spent first.
  final List<CategorySpend> categoryBreakdown;

  /// Top five payees.
  final List<(String, double)> topMerchants;

  /// Every active recurring charge.
  final double subscriptionsMonthlyCost;

  /// Ready notes.
  final List<String> insights;

  /// The safe-spend gauge.
  final SpendingPower spendingPower;

  /// Null under five expenses.
  final BehaviorProfile? behaviorProfile;

  /// Null without a previous month.
  final MonthComparison? monthComparison;

  /// Any transaction this month.
  final bool hasEnoughData;
}

const List<String> _fixedKeywords = <String>[
  'إيجار',
  'ايجار',
  'قسط',
  'أقساط',
  'اقساط',
  'rent',
  'installment',
  'mortgage',
  'loan',
];

bool _isFixed(Subscription s) {
  if (s.type == 'bill' || s.type == 'installment' || s.type == 'rent') {
    return true;
  }
  final hay = '${s.category ?? ''} ${s.title}'.toLowerCase();
  return _fixedKeywords.any(hay.contains);
}

/// Kotlin's `financialHealthScore` — money only.
int financialHealthScore({
  required double budget,
  required double totalSpent,
  required int overBudgetCategories,
  required double discretionaryMonthlyCost,
}) {
  var score = 100;
  if (budget > 0) {
    final pct = (totalSpent / budget * 100).toInt();
    score -= pct >= 100
        ? 40
        : pct >= 90
        ? 30
        : pct >= 75
        ? 15
        : 0;
  }
  score -= overBudgetCategories * 8;
  if (budget > 0 && discretionaryMonthlyCost > budget * 0.25) score -= 10;
  return score.clamp(0, 100);
}

const Map<int, String> _arabicDays = <int, String>{
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

/// Builds the report. [local] converts an instant to the account's wall
/// clock; [today] is the account's civil date; [predictDaysLeft] is the
/// consumption learner's forecast for a pantry item.
BrainReport buildBrainReport({
  required List<ZadTransaction> transactions,
  required List<Subscription> subscriptions,
  required List<String> pantryNames,
  required Map<String, double> categoryBudgets,
  required List<String> standardCategories,
  required double budget,
  required DateTime today,
  required DateTime Function(DateTime) local,
  required int? Function(String) predictDaysLeft,
  required String Function(double) money,
}) {
  DateTime day(ZadTransaction t) {
    final l = local(t.createdAt);
    return DateTime.utc(l.year, l.month, l.day);
  }

  final monthStart = DateTime.utc(today.year, today.month);
  final monthTx = transactions.where((t) => !day(t).isBefore(monthStart));
  final totalSpent = monthTx
      .where((t) => t.kind == TxnKind.expense)
      .fold<double>(0, (s, t) => s + t.amount);
  final totalIncome = monthTx
      .where((t) => t.kind == TxnKind.income)
      .fold<double>(0, (s, t) => s + t.amount);
  final remaining = budget <= 0 ? null : budget - totalSpent + totalIncome;

  final spentByCategory = <String, double>{};
  for (final t in monthTx.where((t) => t.kind == TxnKind.expense)) {
    final c = t.category ?? 'أخرى';
    spentByCategory[c] = (spentByCategory[c] ?? 0) + t.amount;
  }
  final breakdown =
      <CategorySpend>[
          for (final c in standardCategories)
            CategorySpend(
              category: c,
              spent: spentByCategory[c] ?? 0,
              budget: categoryBudgets[c] ?? 0,
            ),
        ].where((c) => c.spent > 0 || c.budget > 0).toList()
        ..sort((a, b) => b.spent.compareTo(a.spent));

  final daily = <double>[
    for (var o = 13; o >= 0; o--)
      transactions
          .where(
            (t) =>
                t.kind == TxnKind.expense &&
                day(t) == today.subtract(Duration(days: o)),
          )
          .fold<double>(0, (s, t) => s + t.amount),
  ];

  final merchants = <String, double>{};
  for (final t in monthTx.where((t) => t.kind == TxnKind.expense)) {
    final k = t.merchantName ?? t.title;
    merchants[k] = (merchants[k] ?? 0) + t.amount;
  }
  final topMerchants =
      (merchants.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => (e.key, e.value))
          .toList();

  final active = subscriptions.where((s) => s.isActive).toList();
  final subsMonthly = active.fold<double>(0, (s, x) => s + x.amount);
  final discretionary = active.where((s) => !_isFixed(s)).toList();
  final discretionaryCost = discretionary.fold<double>(
    0,
    (s, x) => s + x.amount,
  );

  final forecasts = <(String, int)>[
    for (final n in pantryNames)
      if (predictDaysLeft(n) case final d?) (n, d),
  ]..sort((a, b) => a.$2.compareTo(b.$2));

  final score = financialHealthScore(
    budget: budget,
    totalSpent: totalSpent,
    overBudgetCategories: breakdown.where((c) => c.isOverBudget).length,
    discretionaryMonthlyCost: discretionaryCost,
  );
  final label = score >= 85
      ? 'ممتاز 🌟'
      : score >= 65
      ? 'جيد 👍'
      : score >= 40
      ? 'يحتاج انتباه ⚠️'
      : 'خطر 🚨';

  final insights = <String>[];
  if (breakdown.isNotEmpty) {
    final top = breakdown.first;
    insights.add(
      'أعلى إنفاقك هذا الشهر: ${top.category} (${money(top.spent)})',
    );
  }
  for (final c in breakdown.where((c) => c.isOverBudget)) {
    insights.add(
      '⛔ تجاوزت ميزانية ${c.category} بـ${money(c.spent - c.budget)}',
    );
  }
  if (discretionaryCost > 0) {
    insights.add(
      'اشتراكاتك النشطة تكلفك ${money(discretionaryCost)} شهرياً '
      '(${money(discretionaryCost * 12)} سنوياً)',
    );
    if (budget > 0 && discretionaryCost > budget * 0.2) {
      final most = discretionary.reduce((a, b) => a.amount >= b.amount ? a : b);
      insights.add(
        '💡 اشتراكاتك ${(discretionaryCost / budget * 100).toInt()}% من '
        'ميزانيتك — راجع ${most.title} (${money(most.amount)}) لو مش مستخدمه',
      );
    }
    const streaming = <String>[
      'netflix',
      'نتفلكس',
      'شاهد',
      'shahid',
      'osn',
      'prime',
      'disney',
    ];
    final streams = subscriptions
        .where(
          (s) =>
              s.isActive &&
              streaming.any((k) => s.title.toLowerCase().contains(k)),
        )
        .toList();
    if (streams.length >= 2) {
      final cheapest = streams.reduce((a, b) => a.amount <= b.amount ? a : b);
      insights.add(
        '📺 عندك ${streams.length} خدمات بث — إلغاء واحدة يوفر لك '
        '${money(cheapest.amount)} شهرياً',
      );
    }
  }
  for (final (name, days) in forecasts) {
    if (days <= 2) {
      insights.add('🛒 $name متوقع يخلص خلال ${days < 0 ? 0 : days} يوم');
      break;
    }
  }
  final spentDays = daily.where((d) => d > 0).toList();
  final avgDaily = spentDays.isEmpty
      ? 0.0
      : spentDays.reduce((a, b) => a + b) / spentDays.length;
  if (avgDaily > 0 && remaining != null && remaining > 0) {
    insights.add(
      'بمعدل إنفاقك الحالي (${money(avgDaily)}/يوم)، الرصيد يكفي '
      '${(remaining / avgDaily).toInt()} يوم',
    );
  }

  final monthLength = DateTime.utc(today.year, today.month + 1, 0).day;
  final daysLeft = (monthLength - today.day + 1).clamp(1, 31);
  final dailySafe = remaining == null
      ? null
      : (remaining / daysLeft).clamp(0, double.infinity).toDouble();
  final currentDailyAvg = totalSpent / today.day;
  final powerPct = budget > 0 && remaining != null
      ? (remaining / budget * 100).toInt().clamp(0, 100)
      : null;
  final power = SpendingPower(
    dailySafeSpend: dailySafe,
    currentDailyAvg: currentDailyAvg,
    daysLeftInMonth: daysLeft,
    powerPct: powerPct,
    status: switch (powerPct) {
      null => 'غير محدد',
      >= 60 => 'قوي 💪',
      >= 35 => 'متوازن ⚖️',
      >= 15 => 'ضعيف ⚠️',
      _ => 'خطر 🚨',
    },
  );

  final expenses = transactions.where((t) => t.isExpense).toList();
  BehaviorProfile? profile;
  if (expenses.length >= 5) {
    final byDay = <int, double>{};
    var weekend = 0.0;
    for (final t in expenses) {
      final w = local(t.createdAt).weekday;
      byDay[w] = (byDay[w] ?? 0) + t.amount;
      if (w == DateTime.friday || w == DateTime.saturday) weekend += t.amount;
    }
    final total = expenses.fold<double>(0, (s, t) => s + t.amount);
    final avg = total / expenses.length;
    final top = byDay.entries.isEmpty
        ? null
        : byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final since = today.subtract(const Duration(days: 30));
    profile = BehaviorProfile(
      topSpendingDay: top == null ? 'غير معروف' : _arabicDays[top.key]!,
      weekendSharePct: (weekend / (total > 0 ? total : 1) * 100).toInt(),
      avgTransaction: avg,
      impulsePurchases: expenses
          .where((t) => day(t).isAfter(since) && t.amount > avg * 2)
          .length,
    );
  }

  final lastMonthStart = DateTime.utc(today.year, today.month - 1);
  final lastMonth = transactions
      .where(
        (t) =>
            t.isExpense &&
            !day(t).isBefore(lastMonthStart) &&
            day(t).isBefore(monthStart),
      )
      .toList();
  MonthComparison? comparison;
  if (lastMonth.isNotEmpty) {
    final cutoff = lastMonthStart.add(Duration(days: today.day - 1));
    final sameDay = lastMonth
        .where((t) => !day(t).isAfter(cutoff))
        .fold<double>(0, (s, t) => s + t.amount);
    comparison = MonthComparison(
      thisMonthSpent: totalSpent,
      lastMonthSpent: sameDay,
      deltaPct: sameDay > 0
          ? ((totalSpent - sameDay) / sameDay * 100).toInt()
          : 0,
    );
  }

  if (dailySafe != null && dailySafe > 0 && currentDailyAvg > dailySafe) {
    insights.insert(
      0,
      '⚡ معدل صرفك اليومي (${money(currentDailyAvg)}) أعلى من الآمن '
      '(${money(dailySafe)}) — خفف شوية',
    );
  }
  if (comparison != null) {
    if (comparison.deltaPct <= -10) {
      insights.insert(
        0,
        '🎉 صرفت ${-comparison.deltaPct}% أقل من نفس الفترة الشهر الماضي — '
        'وفرت ${money(comparison.lastMonthSpent - comparison.thisMonthSpent)}!',
      );
    } else if (comparison.deltaPct >= 15) {
      insights.insert(
        0,
        '📈 صرفك زاد ${comparison.deltaPct}% عن نفس الفترة الشهر الماضي',
      );
    }
  }
  if (profile != null && profile.impulsePurchases >= 3) {
    insights.add(
      '🛍️ ${profile.impulsePurchases} مشتريات اندفاعية آخر 30 يوم (أكبر من '
      'ضعف متوسطك)',
    );
  }

  return BrainReport(
    healthScore: score,
    healthLabel: label,
    totalSpent: totalSpent,
    totalIncome: totalIncome,
    budget: budget,
    remaining: remaining,
    categoryBreakdown: breakdown,
    topMerchants: topMerchants,
    subscriptionsMonthlyCost: subsMonthly,
    insights: insights,
    spendingPower: power,
    behaviorProfile: profile,
    monthComparison: comparison,
    hasEnoughData: monthTx.isNotEmpty,
  );
}

/// Kotlin's `buildExportText`, line for line.
String buildExportText(
  BrainReport r, {
  required DateTime today,
  required String Function(double) money,
}) {
  final number = NumberFormat('#,##0.##', 'en');
  const unknown = 'لسه غير محدد';
  final safe = r.spendingPower.dailySafeSpend;
  final b = StringBuffer()
    ..writeln('📊 تقرير زاد المالي — ${today.month}/${today.year}')
    ..writeln('═══════════════════════════')
    ..writeln('الصحة المالية: ${r.healthScore}/100 (${r.healthLabel})')
    ..writeln(
      'قوة الصرف: ${r.spendingPower.status} — الآمن يومياً: '
      '${safe == null ? unknown : money(safe)}',
    )
    ..writeln()
    ..writeln('💰 الأرقام:')
    ..writeln('• الميزانية: ${money(r.budget)}')
    ..writeln('• المصروف: ${money(r.totalSpent)}')
    ..writeln('• الدخل: ${money(r.totalIncome)}')
    ..writeln(
      '• المتبقي: ${r.remaining == null ? unknown : money(r.remaining!)}',
    );
  if (r.subscriptionsMonthlyCost > 0) {
    b.writeln('• الاشتراكات: ${money(r.subscriptionsMonthlyCost)}/شهر');
  }
  if (r.monthComparison case final mc?) {
    b
      ..writeln()
      ..writeln('📅 مقارنة بالشهر الماضي (نفس الفترة):')
      ..writeln(
        '• هذا الشهر: ${money(mc.thisMonthSpent)} | الماضي: '
        '${money(mc.lastMonthSpent)} (${mc.deltaPct >= 0 ? '+' : ''}'
        '${mc.deltaPct}%)',
      );
  }
  if (r.categoryBreakdown.isNotEmpty) {
    b
      ..writeln()
      ..writeln('🗂️ حسب الفئة:');
    for (final c in r.categoryBreakdown) {
      b.write('• ${c.category}: ${money(c.spent)}');
      if (c.budget > 0) {
        b.write(' من ${number.format(c.budget)} (${c.pctUsed}%)');
      }
      b.writeln();
    }
  }
  if (r.topMerchants.isNotEmpty) {
    b
      ..writeln()
      ..writeln('🏪 أعلى الجهات:');
    for (final (name, amount) in r.topMerchants) {
      b.writeln('• $name: ${money(amount)}');
    }
  }
  if (r.behaviorProfile case final bp?) {
    b
      ..writeln()
      ..writeln('🧠 سلوكك المالي:')
      ..writeln('• أكثر يوم صرف: ${bp.topSpendingDay}')
      ..writeln('• صرف الويكند: ${bp.weekendSharePct}% من الإجمالي')
      ..writeln('• متوسط المعاملة: ${money(bp.avgTransaction)}');
    if (bp.impulsePurchases > 0) {
      b.writeln('• مشتريات اندفاعية (30 يوم): ${bp.impulsePurchases}');
    }
  }
  if (r.insights.isNotEmpty) {
    b
      ..writeln()
      ..writeln('💡 ملاحظات زاد:');
    for (final i in r.insights.take(6)) {
      b.writeln('• $i');
    }
  }
  b
    ..writeln()
    ..writeln('— تقرير من تطبيق زاد 🥕');
  return b.toString();
}
