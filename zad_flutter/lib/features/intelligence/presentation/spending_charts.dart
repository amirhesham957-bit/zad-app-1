/// The brain screen's charts: what was spent each day of the last two weeks,
/// and where it went. The owner (2026-10-01): «صفحة عقل زاد مفهاش تحليلات
/// وجرافات» — the numbers were there, drawn as text.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/intelligence/domain/spending_series.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// Slice colours, one per category (illustrative, not UI chrome).
const List<Color> _slices = <Color>[
  Color(0xFF1B4332),
  Color(0xFF2D6A4F),
  Color(0xFFD08C2A),
  Color(0xFFB85C38),
  Color(0xFF5B7DB1),
  Color(0xFF9AA5A0),
];

String _money(double v) => NumberFormat.compact(locale: 'en').format(v);

/// The two charts in one card.
class SpendingCharts extends ConsumerWidget {
  /// Creates the card for [rows] in [currency].
  const new({required this.rows, required this.currency, super.key});

  /// The cached transactions.
  final List<ZadTransaction> rows;

  /// The account's currency.
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    DateTime local(DateTime utc) => tz.TZDateTime.from(utc.toUtc(), zone);
    final now = local(ref.read(nowProvider)());
    final today = DateTime.utc(now.year, now.month, now.day);
    final days = dailySpend(rows, today: today, local: local);
    final monthStart = DateTime.utc(today.year, today.month - 1, today.day);
    final shares = categoryShares(
      rows.where((t) => !local(t.createdAt).isBefore(monthStart)),
    );
    final total = shares.fold<double>(0, (s, e) => s + e.$2);
    final peak = days.fold<double>(0, (m, d) => math.max(m, d.$2));
    final spent14 = days.fold<double>(0, (s, d) => s + d.$2);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('صرفك آخر أسبوعين', style: ZadType.titleMedium),
            Text(
              'الإجمالي ${NumberFormat('#,##0', 'en').format(spent14)} '
              '$currency · متوسط اليوم '
              '${NumberFormat('#,##0', 'en').format(spent14 / 14)}',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.md),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: peak <= 0 ? 1 : peak * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${days[group.x].$1.day}/${days[group.x].$1.month}\n'
                        '${_money(rod.toY)}',
                        ZadType.labelSmall.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i % 3 != 1 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${days[i].$1.day}',
                            style: ZadType.labelSmall.copyWith(
                              color: ZadColors.inkMuted,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: <BarChartGroupData>[
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: days[i].$2,
                            width: 12,
                            color: i == days.length - 1
                                ? ZadColors.mustardOchre
                                : ZadColors.forestEmerald,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (total > 0) ...<Widget>[
              const SizedBox(height: ZadSpacing.xl),
              const Text('صرفك راح فين (آخر شهر)', style: ZadType.titleMedium),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: <PieChartSectionData>[
                          for (var i = 0; i < shares.length; i++)
                            PieChartSectionData(
                              value: shares[i].$2,
                              color: _slices[i % _slices.length],
                              radius: 26,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (var i = 0; i < shares.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _slices[i % _slices.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: ZadSpacing.sm),
                                Expanded(
                                  child: Text(
                                    shares[i].$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZadType.bodySmall,
                                  ),
                                ),
                                Text(
                                  '${(shares[i].$2 / total * 100).round()}%',
                                  style: ZadType.labelMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
