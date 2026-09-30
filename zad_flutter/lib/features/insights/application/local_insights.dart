/// Kotlin's local `insights` list (`ZadViewModel._insights`), without the
/// part that is a model call:
///
/// - `analyzeSubscriptionUsage`: an active subscription whose name appears in
///   old transactions but not in the last 60 days is «اشتراك غير مستغل»
///   (Warning); otherwise one costing over 1,000 a year is «تكلفة اشتراك
///   عالية» (Tip). Both offer `cancel_subscription`.
/// - `analyzeBudgetOverruns`: a category at 90% or more of its ceiling this
///   calendar month is «ميزانية X على وشك النفاد» (Warning), offering
///   `increase_budget` to 1.2× the spending, rounded up to 50.
/// - The first-run tip «أهلاً بك في زاد» when there is nothing yet.
///
/// Kotlin's `generateBehavioralInsights` is `spending_insights` — a model call
/// on every data change — and is left out under the owner's standing
/// decision. `detectSpendingAnomaly` is never called in Kotlin.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/presentation/finances_screen.dart'
    show categoryBudgetsProvider;
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Kotlin's `AiInsight`.
class LocalInsight {
  /// Creates one.
  const new({
    required this.title,
    required this.description,
    required this.type,
    this.actionType,
    this.actionRefId,
    this.actionAmount,
  });

  /// The headline.
  final String title;

  /// The detail.
  final String description;

  /// `Alert`, `Warning` or `Tip`.
  final String type;

  /// `cancel_subscription` or `increase_budget`.
  final String? actionType;

  /// The subscription id or the category.
  final String? actionRefId;

  /// The yearly saving or the suggested ceiling.
  final double? actionAmount;

  /// Kotlin's banner and bell filter.
  bool get isAlert => type == 'Alert' || type == 'Warning';
}

String _money(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// The list, newest rules first as Kotlin inserts them.
final localInsightsProvider = Provider<List<LocalInsight>>((ref) {
  final rows = ref.watch(transactionsControllerProvider).rows;
  final pantry = ref.watch(pantryControllerProvider.select((v) => v.items));
  final subs = ref.watch(subscriptionsControllerProvider).items;
  final ceilings = ref.watch(categoryBudgetsProvider);
  final currency = ref.watch(
    budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
  );
  final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
  final now = ref.read(nowProvider)();
  final local = tz.TZDateTime.from(now.toUtc(), zone);

  final out = <LocalInsight>[];

  // analyzeBudgetOverruns — this calendar month, expenses by category.
  final spent = <String, double>{};
  for (final t in rows) {
    if (!t.isExpense) continue;
    final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
    if (d.year != local.year || d.month != local.month) continue;
    final c = t.category ?? 'أخرى';
    spent[c] = (spent[c] ?? 0) + t.amount;
  }
  for (final MapEntry(key: cat, value: budget) in ceilings.entries) {
    final s = spent[cat] ?? 0;
    if (budget <= 0 || s < budget * 0.9) continue;
    out.add(
      LocalInsight(
        title: 'ميزانية $cat على وشك النفاد',
        description:
            'صرفت ${_money(s, currency)} من أصل ${_money(budget, currency)} '
            'في $cat هذا الشهر.',
        type: 'Warning',
        actionType: 'increase_budget',
        actionRefId: cat,
        actionAmount: (s * 1.2 / 50).ceil() * 50.0,
      ),
    );
  }

  // analyzeSubscriptionUsage — inserted ahead, as Kotlin's addAll(0, …).
  final subInsights = <LocalInsight>[];
  for (final sub in subs.where((s) => s.isActive)) {
    final yearly = sub.amount * 12;
    final related = <ZadTransaction>[
      for (final t in rows)
        if (sub.title.isNotEmpty &&
            t.title.toLowerCase().contains(sub.title.toLowerCase()))
          t,
    ];
    final recent = related.any((t) => now.difference(t.createdAt).inDays < 60);
    if (!recent && related.isNotEmpty) {
      subInsights.add(
        LocalInsight(
          title: 'اشتراك غير مستغل: ${sub.title}',
          description:
              'لم نلاحظ أي نشاط لاشتراك ${sub.title} مؤخراً. التوفير المحتمل: '
              '${_money(yearly, currency)} سنوياً عند الإلغاء.',
          type: 'Warning',
          actionType: 'cancel_subscription',
          actionRefId: sub.id,
          actionAmount: yearly,
        ),
      );
    } else if (yearly > 1000) {
      subInsights.add(
        LocalInsight(
          title: 'تكلفة اشتراك عالية: ${sub.title}',
          description:
              'هذا الاشتراك يكلفك ${_money(yearly, currency)} سنوياً. هل يستحق '
              'الاستمرار؟',
          type: 'Tip',
          actionType: 'cancel_subscription',
          actionRefId: sub.id,
          actionAmount: yearly,
        ),
      );
    }
  }

  final all = <LocalInsight>[...subInsights, ...out];
  if (rows.isEmpty && pantry.isEmpty) {
    all.add(
      const LocalInsight(
        title: 'أهلاً بك في زاد',
        description:
            'أضف معاملات أو عناصر للمخزون لنتمكن من تحليل بياناتك '
            'وتقديم توصيات ذكية.',
        type: 'Tip',
      ),
    );
  }
  return all;
});

/// Kotlin's banner and bell list: Alert first, then Warning.
final alertInsightsProvider = Provider<List<LocalInsight>>((ref) {
  final list = ref.watch(localInsightsProvider).where((i) => i.isAlert);
  return <LocalInsight>[
    ...list.where((i) => i.type == 'Alert'),
    ...list.where((i) => i.type != 'Alert'),
  ];
});
