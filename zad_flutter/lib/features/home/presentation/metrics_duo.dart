/// Kotlin's `ZadMinimalMetricsDuo`: two small white cards under the green one —
/// what can be spent per day without running out, and how many days are left.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// The safe daily spend: what is spendable spread over the days that are
/// left, or all of it on the last day — Kotlin's arithmetic exactly.
double safeDailySpend({required double spendable, required int daysLeft}) =>
    daysLeft > 0 ? spendable / daysLeft : spendable;

/// The pair.
class HomeMetricsDuo extends StatelessWidget {
  /// Creates the pair.
  const new({
    required this.spendable,
    required this.daysLeft,
    required this.currency,
    super.key,
  });

  /// What can be spent, as the green card shows it.
  final double spendable;

  /// Days left in the period.
  final int daysLeft;

  /// The account's currency.
  final String currency;

  @override
  Widget build(BuildContext context) {
    final daily = safeDailySpend(spendable: spendable, daysLeft: daysLeft);
    return Row(
      children: <Widget>[
        Expanded(
          child: _Metric(
            label: 'معدل الصرف اليومي الآمن',
            value: '${_money(daily < 0 ? 0 : daily)} $currency',
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: _Metric(label: 'يوم متبقي', value: '$daysLeft يوم'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

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
      ],
    ),
  );
}

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);
