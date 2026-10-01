/// «موجز زاد النهارده»: the few things that matter today, out of what is
/// already on the device.
///
/// زاد's home used to be seventeen section tiles and a card per feature — the
/// customer had to go and look. The brief is the brain looking for them: a
/// dose that is due, what ran out, an instalment due in the next days, a
/// budget that is already over (owner, 2026-09-30,
/// docs/agent/ZAD_BRAIN_PLAN.md). Pure: no clock, no network, no model call —
/// the screen opens on it instantly (CLAUDE.md: no LLM call on screen open).
library;

import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/inventory/domain/product_family.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/subscriptions/domain/bnpl.dart';
import 'package:zad/shared/subscriptions/domain/subscription.dart';

/// What one line of the brief is about.
enum BriefKind {
  /// A dose to take now.
  doseDue,

  /// Doses today that passed their window with nothing recorded.
  dosesMissed,

  /// More spent than the period had.
  overspent,

  /// A subscription, bill or instalment due within a few days.
  renewal,

  /// Things that ran out or are running low.
  shortage,
}

/// One line of the brief.
class BriefItem {
  /// Creates a line.
  const new({
    required this.kind,
    required this.title,
    required this.detail,
    this.dose,
  });

  /// What it is about, which decides where a tap goes.
  final BriefKind kind;

  /// The line.
  final String title;

  /// The line under it.
  final String detail;

  /// For [BriefKind.doseDue]: the dose «خدتها» records.
  final DoseSlot? dose;
}

String _money(double v, String currency) {
  final pattern = v % 1 == 0 ? '#,##0' : '#,##0.##';
  return '${NumberFormat(pattern, 'en').format(v)} $currency'.trim();
}

String _whenIn(int days) => switch (days) {
  <= 0 => 'النهارده',
  1 => 'بكرة',
  2 => 'بعد بكرة',
  _ => 'بعد $days أيام',
};

/// The brief for [today] (a civil date in the account's zone) at [now], most
/// urgent first, at most [max] lines. Empty when nothing needs the customer.
List<BriefItem> dailyBrief({
  required List<InventoryItem> pantry,
  required List<DoseSlot> doses,
  required List<Subscription> subscriptions,
  required DateTime today,
  required DateTime now,
  double? spendable,
  String currency = '',
  int renewalWithinDays = 3,
  int max = 5,
}) {
  final items = <BriefItem>[];

  // Doses first: a missed tablet costs more than a missed discount.
  DoseSlot? due;
  var missed = 0;
  for (final slot in doses) {
    switch (slot.stateAt(now)) {
      case DoseState.due:
        due ??= slot;
      case DoseState.missed:
        missed++;
      case DoseState.upcoming || DoseState.taken:
        break;
    }
  }
  if (due != null) {
    items.add(
      BriefItem(
        kind: BriefKind.doseDue,
        title: 'وقت جرعة ${due.medicine.name}',
        detail: 'ميعادها ${due.time} — دوس «خدتها» لما تاخدها',
        dose: due,
      ),
    );
  }
  if (missed > 0) {
    items.add(
      BriefItem(
        kind: BriefKind.dosesMissed,
        title: missed == 1 ? 'جرعة فاتت' : '$missed جرعات فاتوا',
        detail: 'افتح الصيدلية وسجّل اللي اتاخد',
      ),
    );
  }

  if (spendable != null && spendable < 0) {
    items.add(
      BriefItem(
        kind: BriefKind.overspent,
        title: 'صرفت أكتر من المتاح بـ${_money(-spendable, currency)}',
        detail: 'شوف فلوسي — زاد يقدر يقترح تقلل منين',
      ),
    );
  }

  final soon = <(Subscription, int)>[
    for (final s in subscriptions)
      if (s.isActive)
        if (s.nextRenewalFrom(today) case final next?)
          if (next.difference(today).inDays case final days
              when days >= 0 && days <= renewalWithinDays)
            (s, days),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  for (final (s, days) in soon.take(2)) {
    final bnpl = bnplProviderOf(s.title, s.provider);
    items.add(
      BriefItem(
        kind: BriefKind.renewal,
        title: bnpl != null
            ? 'قسط ${bnpl.name} ${_whenIn(days)}'
            : '${s.title} ${_whenIn(days)}',
        detail: _money(s.amount, currency),
      ),
    );
  }

  final short = <String>[
    for (final g in groupPantry(pantry))
      if (g.isLow) g.name,
  ];
  if (short.isNotEmpty) {
    final named = short.take(3).join('، ');
    final more = short.length > 3 ? ' و${short.length - 3} كمان' : '';
    items.add(
      BriefItem(
        kind: BriefKind.shortage,
        title: 'ناقصك $named$more',
        detail: 'افتح بيتي وضيفهم لقايمة التسوق',
      ),
    );
  }

  return items.take(max).toList();
}
