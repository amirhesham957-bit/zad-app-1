/// Kotlin's `ZadMinimalMetricsDuo`: two small white cards under the green one —
/// what can be spent per day without running out, and how many days are left
/// until payday (today included, like the server and the brain), with the
/// payday's date: «14 يوم متبقي» on the 1st read as a bug when the cycle
/// actually ran to the 16th (owner, 2026-10-01).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/budget/domain/event_day_budget.dart';
import 'package:zad/shared/budget/domain/safe_daily_spend.dart';

/// The pair.
class HomeMetricsDuo extends StatelessWidget {
  /// Creates the pair.
  const new({
    required this.spendable,
    required this.daysLeft,
    required this.currency,
    this.payday,
    this.event,
    super.key,
  });

  /// Today's share when an outing in the coming week reweighs the days
  /// (الشريحة ٤٠), with the line saying why. Null = the plain division.
  final ({EventDayBudget budget, String caption})? event;

  /// What can be spent, as the green card shows it.
  final double spendable;

  /// Days left in the period.
  final int daysLeft;

  /// The account's currency.
  final String currency;

  /// The first day of the next salary cycle, or null for a calendar month.
  final DateTime? payday;

  @override
  Widget build(BuildContext context) {
    final daily =
        event?.budget.today ??
        safeDailySpend(spendable: spendable, daysLeft: daysLeft);
    return Row(
      children: <Widget>[
        Expanded(
          child: _Metric(
            label: 'معدل الصرف اليومي الآمن',
            value: '${_money(daily < 0 ? 0 : daily)} $currency',
            caption: event?.caption,
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: _Metric(
            label: payday == null ? 'لحد آخر الشهر' : 'لحد القبض',
            value: '$daysLeft يوم',
            caption: payday == null
                ? null
                : 'يوم ${payday!.day} ${_arabicMonths[payday!.month - 1]}',
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const new({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => ZadCard(
    radius: ZadRadii.cardLarge,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZadType.labelMedium.copyWith(color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: ZadSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: ZadType.titleLarge.copyWith(color: ZadColors.ink),
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
      ],
    ),
  );
}

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

const List<String> _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];
