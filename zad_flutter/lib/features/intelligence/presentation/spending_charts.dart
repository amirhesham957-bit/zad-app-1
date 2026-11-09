/// Where the month's money went, as a ring that answers a touch. The daily
/// line above it is `brain_pulse.dart`.
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
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

/// The ring and its legend in one card.
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
    final monthStart = DateTime.utc(today.year, today.month - 1, today.day);
    final shares = categoryShares(
      rows.where((t) => !local(t.createdAt).isBefore(monthStart)),
    );
    final total = shares.fold<double>(0, (s, e) => s + e.$2);
    if (total <= 0) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.sheet),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('صرفك راح فين (آخر شهر)', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.md),
            _Ring(shares: shares, total: total, currency: currency),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatefulWidget {
  const new({
    required this.shares,
    required this.total,
    required this.currency,
  });

  final List<(String, double)> shares;
  final double total;
  final String currency;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> {
  int? _touched;

  void _touch(int? i) {
    if (i == _touched) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _touched = i);
  }

  @override
  Widget build(BuildContext context) {
    final shares = widget.shares;
    final touched = _touched != null && _touched! < shares.length
        ? _touched
        : null;
    final still = MediaQuery.disableAnimationsOf(context);
    int percent(int i) => (shares[i].$2 / widget.total * 100).round();

    return Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 150,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final i = response?.touchedSection?.touchedSectionIndex;
                      if (i != null && i >= 0) _touch(i);
                    },
                  ),
                  sections: <PieChartSectionData>[
                    for (var i = 0; i < shares.length; i++)
                      PieChartSectionData(
                        value: shares[i].$2,
                        color: _slices[i % _slices.length],
                        radius: i == touched ? 34 : 26,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: still ? Duration.zero : ZadDuration.quick,
                curve: ZadCurves.standard,
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      touched == null
                          ? _money(widget.total)
                          : '${percent(touched)}%',
                      style: ZadType.titleMedium,
                    ),
                    if (touched == null && widget.currency.isNotEmpty)
                      Text(
                        widget.currency,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < shares.length; i++)
                InkWell(
                  onTap: () => _touch(i == touched ? null : i),
                  borderRadius: BorderRadius.circular(ZadRadii.chip),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
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
                            style: i == touched
                                ? ZadType.labelLarge
                                : ZadType.bodySmall,
                          ),
                        ),
                        Text('${percent(i)}%', style: ZadType.labelMedium),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
