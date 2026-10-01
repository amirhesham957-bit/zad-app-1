/// «سلوكك في الصرف»: when in the week the money goes, where it goes most,
/// and what changed since last month. The owner asked for analysis of
/// spending **and behaviour** on عقل زاد (2026-10-01); the charts above it
/// show amounts, this shows habits. From the cached transactions — no model
/// call.
library;

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

String _money(double v) => NumberFormat('#,##0', 'en').format(v);

/// «القهوة زادت ٤٠٪» / «جديد الشهر ده» / «قلّت ٢٠٪».
String changeLine((String, double, double) c) {
  final (name, now, before) = c;
  if (before <= 0) return '$name: جديد الشهر ده (${_money(now)})';
  final pct = ((now - before) / before * 100).round();
  return pct >= 0
      ? '$name: زادت $pct٪ (${_money(before)} ← ${_money(now)})'
      : '$name: قلّت ${-pct}٪ (${_money(before)} ← ${_money(now)})';
}

/// The card.
class BehaviorCard extends ConsumerWidget {
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
    final week = weekdayAverages(rows, today: today, local: local);
    final monthAgo = today.subtract(const Duration(days: 29));
    final places = topPlaces(
      rows.where((t) => !local(t.createdAt).isBefore(monthAgo)),
    );
    final changes = categoryChanges(rows, today: today, local: local);
    final peak = week.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final hasWeek = peak.$2 > 0;
    if (!hasWeek && places.isEmpty && changes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('سلوكك في الصرف', style: ZadType.titleMedium),
              if (hasWeek) ...<Widget>[
                Text(
                  'أكتر يوم بتصرف فيه: ${peak.$1} — متوسط '
                          '${_money(peak.$2)} $currency'
                      .trim(),
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
                const SizedBox(height: ZadSpacing.md),
                SizedBox(
                  height: 120,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: const BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              week[v.toInt()].$1.substring(0, 2),
                              style: ZadType.labelSmall,
                            ),
                          ),
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (var i = 0; i < week.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: week[i].$2,
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                                color: week[i] == peak
                                    ? ZadColors.mustardOchre
                                    : ZadColors.forestEmerald,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (places.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.lg),
                const Text('أكتر أماكن بتصرف فيها', style: ZadType.labelLarge),
                const SizedBox(height: ZadSpacing.xs),
                for (final (name, total, count) in places)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZadType.bodyMedium,
                          ),
                        ),
                        Text(
                          '${_money(total)} $currency · $count مرة'.trim(),
                          style: ZadType.bodySmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (changes.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.lg),
                const Text(
                  'اتغيّر إيه عن الشهر اللي فات',
                  style: ZadType.labelLarge,
                ),
                const SizedBox(height: ZadSpacing.xs),
                for (final c in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZadSpacing.xs),
                    child: Text(changeLine(c), style: ZadType.bodyMedium),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
