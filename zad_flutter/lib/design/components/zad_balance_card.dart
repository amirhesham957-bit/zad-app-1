/// The green card.
///
/// One surface carries the answer to the only question the user opens this app
/// for: how much is left, and is that a lot or a little for where we are in the
/// month. Everything on it serves that sentence.
///
/// It reports the **salary cycle**, not the calendar month — it takes a
/// [BudgetPeriod] and shows that period's own length and its own remaining
/// days. A card that said "30 days" to somebody paid on the 25th would be wrong
/// in a way no test catches.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/elevation.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// The hero balance card.
class ZadBalanceCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.remaining,
    required this.budget,
    required this.currency,
    required this.period,
    required this.now,
    this.onTap,
    this.isStale = false,
    super.key,
  });

  /// What is left to spend this period.
  final double remaining;

  /// What the period started with.
  final double budget;

  /// The account's currency, shown as given — `ج.م`, `ر.س`.
  final String currency;

  /// The period this card is reporting on.
  final BudgetPeriod period;

  /// Now, injected rather than read, so this widget is a pure function of its
  /// inputs and a golden test of it is stable.
  final DateTime now;

  /// Opens the breakdown.
  final VoidCallback? onTap;

  /// Whether these figures came from the cache and have not been confirmed.
  ///
  /// The card still shows them — that is the whole point of the cache — but it
  /// says so, because a number presented with no qualification is a promise.
  final bool isStale;

  double get _spent => math.max(0, budget - remaining);

  /// How much of the budget is gone, 0..1.
  double get _spentFraction => budget <= 0 ? 0 : (_spent / budget).clamp(0, 1);

  /// How much of the period is gone, 0..1.
  double get _periodFraction {
    final total = period.totalDays;
    if (total <= 0) return 0;
    final left = period.daysRemainingFrom(now);
    return ((total - left) / total).clamp(0, 1);
  }

  /// Spending faster than the period is passing.
  ///
  /// The comparison, not the raw number, is what makes the card useful: 60%
  /// spent is calm on day 20 and alarming on day 6.
  bool get _aheadOfPace => _spentFraction > _periodFraction + 0.05;

  @override
  Widget build(BuildContext context) {
    final daysLeft = math.max(0, period.daysRemainingFrom(now));

    return ZadPressable(
      onPressed: onTap,
      semanticLabel:
          'المتبقي ${_money(remaining)} $currency، '
          'باقي $daysLeft يوم',
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: ZadElevation.hero),
        child: ZadSquircleClip(
          radius: ZadRadii.hero,
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: ZadColors.hero),
            child: CustomPaint(
              // Two soft radial glows. They are what stop a large saturated
              // panel reading as flat fill, and they cost one paint — no blur,
              // no saveLayer, nothing per frame.
              painter: const _HeroGlowPainter(),
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Label(
                      isStale: isStale,
                      isCalendarMonth: period.isCalendarMonth,
                    ),
                    const SizedBox(height: ZadSpacing.md),
                    _Figure(amount: remaining, currency: currency),
                    const SizedBox(height: ZadSpacing.xl),
                    _PaceBar(
                      spent: _spentFraction,
                      elapsed: _periodFraction,
                      aheadOfPace: _aheadOfPace,
                    ),
                    const SizedBox(height: ZadSpacing.md),
                    _Footer(
                      daysLeft: daysLeft,
                      spent: _spent,
                      currency: currency,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const new({required this.isStale, required this.isCalendarMonth});

  final bool isStale;

  /// Whether this period is a plain calendar month. The label has to say so:
  /// telling somebody "دورة الراتب" when the app does not know their payday
  /// claims a fact nobody supplied.
  final bool isCalendarMonth;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Flexible(
        child: Text(
          isCalendarMonth ? 'المتبقي هذا الشهر' : 'المتبقي في دورة الراتب',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZadType.labelLarge.copyWith(color: ZadColors.mint100),
        ),
      ),
      if (isStale) ...<Widget>[
        const SizedBox(width: ZadSpacing.sm),
        // A dot, not a spinner. A spinner on a figure says "this is loading";
        // the figure is right here and readable, it is just not confirmed.
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: ZadColors.mustardOchre,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ],
  );
}

class _Figure extends StatelessWidget {
  const new({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: ZadDuration.count,
      curve: ZadCurves.standard,
      builder: (context, value, _) {
        // The figure is masked with a white→mint gradient so a number this
        // large
        // has some depth without introducing a second colour.
        return ShaderMask(
          shaderCallback: (bounds) => ZadColors.heroFigure.createShader(bounds),
          child: Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: <Widget>[
              // Scales down instead of overflowing. A balance in the millions,
              // a four-letter currency, or a user running Android's font size
              // at 1.3 all make this row wider than the card, and a hero
              // figure clipped by a yellow overflow stripe is the worst
              // possible place for that to show up.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _money(value),
                    maxLines: 1,
                    style: ZadType.figure(44).copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.sm),
              Text(
                currency,
                style: ZadType.titleSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The bar, and the mark showing where the period has got to.
///
/// Two quantities on one axis: how much money is gone, and how much time is.
/// Putting them on the same line is the whole idea — the gap between them is
/// the judgement the user would otherwise have to make themselves.
class _PaceBar extends StatelessWidget {
  const new({
    required this.spent,
    required this.elapsed,
    required this.aheadOfPace,
  });

  final double spent;
  final double elapsed;
  final bool aheadOfPace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 10,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              // The track.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                ),
                child: const SizedBox(height: 6, width: double.infinity),
              ),
              // Spent so far. Mustard when it has outrun the calendar, because
              // that is the app's colour for "this needs attention", not red —
              // spending faster than average is not an error.
              AnimatedContainer(
                duration: ZadDuration.settle,
                curve: ZadCurves.standard,
                height: 6,
                width: width * spent,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: aheadOfPace
                        ? const <Color>[
                            ZadColors.mustardOchre,
                            Color(0xFFE9A844),
                          ]
                        : const <Color>[ZadColors.green600, ZadColors.mintGlow],
                  ),
                  borderRadius: BorderRadius.circular(ZadRadii.pill),
                ),
              ),
              // Where the period itself has reached.
              PositionedDirectional(
                start: (width * elapsed).clamp(0, width - 2),
                child: Container(
                  width: 2,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(ZadRadii.pill),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const new({
    required this.daysLeft,
    required this.spent,
    required this.currency,
  });

  final int daysLeft;
  final double spent;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final style = ZadType.bodySmall.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            'اتصرف ${_money(spent)} $currency',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Text(
          daysLeft == 0
              ? 'آخر يوم'
              : 'باقي $daysLeft ${daysLeft <= 10 ? "أيام" : "يوم"}',
          maxLines: 1,
          style: style,
        ),
      ],
    );
  }
}

/// Paints the card's depth.
class _HeroGlowPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    // A specular highlight where the light would fall.
    final specular = Rect.fromCircle(
      center: Offset(size.width * 0.82, -size.height * 0.15),
      radius: size.height * 0.95,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(specular),
    );

    // A mint bloom low on the opposite side. This is the one gesture toward the
    // Web3 look, and it is kept to a single soft blob — the rest of the card is
    // iOS, and two competing idioms on one surface read as neither.
    final bloom = Rect.fromCircle(
      center: Offset(size.width * 0.08, size.height * 1.05),
      radius: size.height * 0.85,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            ZadColors.mintGlow.withValues(alpha: 0.22),
            ZadColors.mintGlow.withValues(alpha: 0),
          ],
        ).createShader(bloom),
    );
  }

  @override
  bool shouldRepaint(_HeroGlowPainter oldDelegate) => false;
}

/// Grouped, at most two decimals, Latin digits.
///
/// Latin digits and not Arabic-Indic: the figure is set in Inter with tabular
/// numerals so a counting balance does not make the row jitter, and that is a
/// property of these glyphs.
String _money(double amount) => NumberFormat('#,##0.##', 'en').format(amount);
