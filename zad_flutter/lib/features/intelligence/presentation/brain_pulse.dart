/// The top of the brain screen: the money as a live instrument. Pick a window,
/// touch the line, and the big figure follows the finger (owner, 2026-11-09:
/// analytics that answer a tap, not cards of text).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/intelligence/domain/spending_series.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

String _whole(double v) => NumberFormat('#,##0', 'en').format(v);

/// The card.
class BrainPulseCard extends ConsumerStatefulWidget {
  /// Creates the card for [rows] in [currency]; [onAsk] sends a question.
  const new({
    required this.rows,
    required this.currency,
    required this.onAsk,
    super.key,
  });

  /// The cached transactions.
  final List<ZadTransaction> rows;

  /// The account's currency.
  final String currency;

  /// Sends a question to the chat.
  final ValueChanged<String> onAsk;

  @override
  ConsumerState<BrainPulseCard> createState() => _BrainPulseState();
}

class _BrainPulseState extends ConsumerState<BrainPulseCard> {
  static const List<int> _windows = <int>[7, 14, 30];

  int _window = 14;

  /// The day under the finger; null shows the whole window.
  int? _picked;

  void _pick(int? day) {
    if (day == _picked) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _picked = day);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final still = MediaQuery.disableAnimationsOf(context);
    final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
    DateTime local(DateTime utc) => tz.TZDateTime.from(utc.toUtc(), zone);
    final now = local(ref.read(nowProvider)());
    final today = DateTime.utc(now.year, now.month, now.day);
    final both = dailySpend(
      widget.rows,
      today: today,
      local: local,
      days: _window * 2,
    );
    final days = both.sublist(_window);
    double sum(Iterable<(DateTime, double)> d) =>
        d.fold<double>(0, (s, e) => s + e.$2);
    final total = sum(days);
    final before = sum(both.take(_window));
    var peak = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i].$2 > days[peak].$2) peak = i;
    }
    final top = categoryShares(
      widget.rows.where((t) => !local(t.createdAt).isBefore(days.first.$1)),
    ).firstOrNull;
    final picked = _picked;
    final pct = before > 0
        ? ((total - before).abs() / before * 100).round()
        : 0;

    String dayLabel(int i) => '${days[i].$1.day}/${days[i].$1.month}';

    return Container(
      padding: const EdgeInsets.all(ZadSpacing.lg),
      decoration: BoxDecoration(
        gradient: ZadColors.hero,
        borderRadius: BorderRadius.circular(ZadRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZadDotPulse(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ZadColors.mintGlow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: Text(
                  l.pulseTitle,
                  style: ZadType.titleMedium.copyWith(color: Colors.white),
                ),
              ),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _window,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: ZadColors.green600,
                onValueChanged: (v) {
                  if (v == null) return;
                  unawaited(HapticFeedback.selectionClick());
                  setState(() {
                    _window = v;
                    _picked = null;
                  });
                },
                children: <int, Widget>{
                  for (final w in _windows)
                    w: SizedBox(
                      width: 36,
                      height: 40,
                      child: Center(
                        child: Text(
                          '$w',
                          style: ZadType.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                },
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            picked == null ? l.pulseLastDays(_window) : dayLabel(picked),
            style: ZadType.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: picked == null ? total : days[picked].$2),
            duration: still ? Duration.zero : ZadDuration.settle,
            curve: ZadCurves.standard,
            builder: (_, v, _) => Text(
              '${_whole(v)} ${widget.currency}'.trim(),
              style: ZadType.figure(36).copyWith(color: Colors.white),
            ),
          ),
          if (picked == null && pct > 0)
            Text(
              total < before
                  ? l.pulseLess(pct.toString())
                  : l.pulseMore(pct.toString()),
              style: ZadType.labelMedium.copyWith(
                color: total < before
                    ? ZadColors.mintGlow
                    : ZadColors.mustardOchre,
              ),
            ),
          const SizedBox(height: ZadSpacing.md),
          SizedBox(
            height: 120,
            // Time runs left to right here even in Arabic, like the bars did.
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: math.max(days[peak].$2 * 1.2, 1),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: false,
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions) return;
                    final spots = response?.lineBarSpots;
                    if (spots == null || spots.isEmpty) return;
                    _pick(spots.first.spotIndex);
                  },
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: <FlSpot>[
                      for (final (i, d) in days.indexed)
                        FlSpot(i.toDouble(), d.$2),
                    ],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: ZadColors.mintGlow,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: picked != null,
                      checkToShowDot: (spot, _) => spot.x.toInt() == picked,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: ZadColors.mintGlow,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          ZadColors.mintGlow.withValues(alpha: 0.35),
                          ZadColors.mintGlow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: still ? Duration.zero : ZadDuration.enter,
              curve: ZadCurves.standard,
            ),
          ),
          const SizedBox(height: ZadSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _Tile(
                  label: l.pulseDaily,
                  value: _whole(total / _window),
                  onTap: () => _pick(null),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: _Tile(
                  label: l.pulsePeak,
                  value: days[peak].$2 > 0 ? dayLabel(peak) : '—',
                  selected: picked == peak,
                  onTap: days[peak].$2 > 0 ? () => _pick(peak) : null,
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Expanded(
                child: _Tile(
                  label: l.pulseTop,
                  value: top?.$1 ?? '—',
                  onTap: top == null
                      ? null
                      : () => widget.onAsk(l.pulseAskPrompt(top.$1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: ZadDuration.quick,
    curve: ZadCurves.standard,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: selected ? 0.26 : 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZadRadii.chip),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZadType.labelLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
