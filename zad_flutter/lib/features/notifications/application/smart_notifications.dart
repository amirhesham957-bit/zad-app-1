/// Kotlin's `generateSmartNotifications`: after the notifications load, the
/// four local checks that write `app_notifications` rows for this account
/// (the bell reads them back like any other):
///
/// 1. «⚠️ تنبيه الميزانية — N%» at 85% of the monthly ceiling;
/// 2. «🔔 تجديد X قريب!» for a renewal within three days;
/// 3. «📦 مخزون منخفض» for up to three low items (unless the customer
///    turned «تنبيهات نقص المخزون» off);
/// 4. «🤔 هل خلص X؟» for up to two items the learner thinks ran out.
///
/// Each is skipped while an unread one like it is already there, exactly as
/// Kotlin checks. All local — no model call.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/alerts/data/alert_prefs.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/inventory/application/pantry_controller.dart';
import 'package:zad/features/inventory/data/consumption_learner.dart';
import 'package:zad/features/notifications/domain/app_notification.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';

String _money(double v, String currency) =>
    '${NumberFormat('#,##0.##', 'en').format(v)} $currency'.trim();

/// Writes the alerts that are due. Returns how many were written.
Future<int> generateSmartNotifications(
  Ref ref,
  List<AppNotification> existing,
) async {
  final client = ref.read(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;

  final unread = existing.where((n) => !n.isRead).toList();
  bool unreadWith(bool Function(String title) test) =>
      unread.any((n) => test(n.title));
  final currency = ref.read(budgetControllerProvider).snapshot?.currency ?? '';
  final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
  final local = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final today = DateTime.utc(local.year, local.month, local.day);
  final alerts = <(String, String)>[];

  // 1. The budget at 85% — this calendar month, as BudgetMath.spentThisMonth.
  final limit = ref.read(settingsControllerProvider).settings?.monthlyLimit;
  if (limit != null && limit > 0) {
    var spent = 0.0;
    for (final t in ref.read(transactionsControllerProvider).rows) {
      if (!t.isExpense) continue;
      final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
      if (d.year == local.year && d.month == local.month) spent += t.amount;
    }
    if (spent >= limit * 0.85) {
      final pct = (spent / limit * 100).toInt();
      if (!unreadWith((t) => t.contains('ميزانية') && t.contains('$pct%'))) {
        alerts.add((
          '⚠️ تنبيه الميزانية — $pct%',
          'لقد صرفت ${_money(spent, currency)} من ميزانيتك '
              '${_money(limit, currency)}. راجع مصاريفك!',
        ));
      }
    }
  }

  // 2. A renewal within three days.
  for (final sub in ref.read(subscriptionsControllerProvider).items) {
    final raw = sub.renewalDate;
    if (!sub.isActive || raw == null || raw.length < 10) continue;
    final date = DateTime.tryParse(raw.substring(0, 10));
    if (date == null) continue;
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;
    if (days < 0 || days > 3) continue;
    if (unreadWith((t) => t.contains(sub.title))) continue;
    alerts.add((
      '🔔 تجديد ${sub.title} قريب!',
      'سيتجدد اشتراكك في ${sub.title} بمبلغ ${_money(sub.amount, currency)} '
          'خلال $days أيام.',
    ));
  }

  // 3. Low stock (the pantry already puts shortages on the list).
  final low = ref
      .read(pantryControllerProvider)
      .items
      .where((i) => i.quantity <= (i.lowStockThreshold ?? 2))
      .take(3)
      .toList();
  if (low.isNotEmpty &&
      ref
          .read(alertPrefsProvider)
          .isEnabledUnlessOff(AlertPrefs.lowInventory) &&
      !unreadWith((t) => t.contains('مخزون منخفض'))) {
    alerts.add((
      '📦 مخزون منخفض',
      'هذه الأصناف نزلت تلقائياً في قائمة التسوق: '
          '${low.map((i) => i.itemName).join('، ')} ✅',
    ));
  }

  // 4. The learner's check-in.
  for (final c in ref.read(checkInCandidatesProvider).take(2)) {
    final name = c.item.itemName;
    if (unreadWith((t) => t.contains(name))) continue;
    alerts.add((
      '🤔 هل خلص $name؟',
      'حسب معدل استهلاكك، المفروض $name قرب يخلص. افتح المخزون وحدّث الكمية '
          'عشان أتعلم أكتر 📊',
    ));
  }

  var written = 0;
  for (final (title, message) in alerts) {
    try {
      await client.from('app_notifications').insert(<String, dynamic>{
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
      });
      written++;
    } on Object catch (e) {
      debugPrint('smart notification not written: $e');
    }
  }
  return written;
}
