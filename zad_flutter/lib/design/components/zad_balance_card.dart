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
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// The hero balance card.
class ZadBalanceCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.spendable,
    required this.spent,
    required this.openingBalance,
    required this.currency,
    required this.period,
    required this.now,
    this.committed = 0,
    this.onTap,
    this.onSetBudget,
    this.onQuickExpense,
    this.onEditBalance,
    this.isStale = false,
    super.key,
  });

  /// What can actually be spent: the balance with committed obligations
  /// already taken out.
  ///
  /// Null when the account has no confirmed limit. `zad_budget_state()` returns
  /// null there on purpose, and the card says so rather than printing a figure
  /// — filling the gap with a zero would assert something nobody told us.
  final double? spendable;

  /// Spent this period, as the server counts it.
  ///
  /// Taken from the server rather than derived from the balance: when an
  /// account has a `balance_anchored_at`, spend is counted from that anchor and
  /// not from the period's start, and no subtraction here would know that.
  final double spent;

  /// What the period opened with, for the pace bar's denominator.
  final double? openingBalance;

  /// Obligations falling due before the period ends. Already out of
  /// [spendable]; shown so the difference is explained rather than mysterious.
  final double committed;

  /// The account's currency, shown as given — `ج.م`, `ر.س`.
  final String currency;

  /// The period this card is reporting on.
  final BudgetPeriod period;

  /// Now, injected rather than read, so this widget is a pure function of its
  /// inputs and a golden test of it is stable.
  final DateTime now;

  /// Opens the breakdown.
  final VoidCallback? onTap;

  /// Offered when there is no confirmed limit.
  final VoidCallback? onSetBudget;

  /// "خصم سريع": the in-card button, and the card's long press — both as in
  /// Kotlin's `ZadWalletHeroCard`.
  final VoidCallback? onQuickExpense;

  /// "تعديل الميزانية": the in-card button and the pencil in the corner.
  final VoidCallback? onEditBalance;

  /// Whether these figures came from the cache and have not been confirmed.
  ///
  /// The card still shows them — that is the whole point of the cache — but it
  /// says so, because a number presented with no qualification is a promise.
  final bool isStale;

  /// How much of the opening balance is gone, 0..1.
  double get _spentFraction {
    final opening = openingBalance;
    if (opening == null || opening <= 0) return 0;
    return (spent / opening).clamp(0, 1);
  }

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
    final amount = spendable;

    return ZadPressable(
      onPressed: amount == null ? onSetBudget : onTap,
      onLongPress: onQuickExpense,
      semanticLabel: amount == null
          ? 'لسه محددتش ميزانيتك'
          : 'المتاح ${_money(amount)} $currency، باقي $daysLeft يوم',
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: ZadElevation.hero),
        child: ZadSquircleClip(
          radius: ZadRadii.hero,
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: ZadColors.wallet),
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
                    if (amount == null)
                      _NoBudgetYet(spent: spent, currency: currency)
                    else ...<Widget>[
                      _Header(
                        isCalendarMonth: period.isCalendarMonth,
                        onEdit: onEditBalance,
                      ),
                      const SizedBox(height: ZadSpacing.md),
                      _Figure(
                        amount: amount,
                        currency: currency,
                        isConfirmed: !isStale,
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                      _Chips(
                        spent: spent,
                        committed: committed,
                        currency: currency,
                      ),
                      const SizedBox(height: ZadSpacing.lg),
                      _PaceBar(
                        spent: _spentFraction,
                        elapsed: _periodFraction,
                        aheadOfPace: _aheadOfPace,
                      ),
                    ],
                    if (onQuickExpense != null ||
                        onEditBalance != null) ...<Widget>[
                      const SizedBox(height: ZadSpacing.lg),
                      _Actions(
                        onQuickExpense: onQuickExpense,
                        onEditBalance: amount == null
                            ? onSetBudget ?? onEditBalance
                            : onEditBalance,
                      ),
                    ],
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

/// What the card says before anybody has confirmed a limit.
///
/// It reports the one thing it does know — what has been spent — and asks for
/// the one thing it does not. It never shows a balance of zero.
class _NoBudgetYet extends StatelessWidget {
  const new({required this.spent, required this.currency});

  final double spent;
  final String currency;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        'اتصرف الفترة دي',
        style: ZadType.labelLarge.copyWith(color: ZadColors.mint100),
      ),
      const SizedBox(height: ZadSpacing.md),
      _Figure(amount: spent, currency: currency),
      const SizedBox(height: ZadSpacing.xl),
      Text(
        'قوللي ميزانيتك الشهرية، وأقدر أقولك المتاح ليك كل يوم.',
        style: ZadType.bodySmall.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    ],
  );
}

/// The card's top row: the card chip and label on one side, the pencil on
/// the other — Kotlin's header, word for word except the label, which says
/// which period the figure belongs to.
class _Header extends StatelessWidget {
  const new({required this.isCalendarMonth, this.onEdit});

  /// Whether this period is a plain calendar month. The label has to say so:
  /// telling somebody "دورة الراتب" when the app does not know their payday
  /// claims a fact nobody supplied.
  final bool isCalendarMonth;

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(
          dimension: 28,
          child: Icon(ZadIcons.card, size: 14, color: Colors.white),
        ),
      ),
      const SizedBox(width: ZadSpacing.sm),
      Expanded(
        child: Text(
          isCalendarMonth ? 'المتاح هذا الشهر' : 'المتاح في دورة الراتب',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZadType.labelLarge.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
      if (onEdit != null)
        Semantics(
          button: true,
          label: 'تعديل الرصيد',
          child: GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            // 44 to touch, 32 to see: the circle is Kotlin's size, the target
            // is the house minimum.
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Icon(
                      ZadIcons.edit,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// المصروف and محجوز, as two glass pills with a coloured dot each.
class _Chips extends StatelessWidget {
  const new({
    required this.spent,
    required this.committed,
    required this.currency,
  });

  final double spent;
  final double committed;
  final String currency;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ZadSpacing.sm,
    runSpacing: ZadSpacing.sm,
    children: <Widget>[
      _Chip(
        dot: ZadColors.spentDot,
        text: 'المصروف ${_money(spent)} $currency',
      ),
      _Chip(
        dot: ZadColors.committedDot,
        text: 'محجوز ${_money(committed)} $currency',
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const new({required this.dot, required this.text});

  final Color dot;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 7),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            style: ZadType.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    ),
  );
}

/// خصم سريع and تعديل الميزانية — buttons inside the card, not floating over
/// the screen, so nothing under them is ever covered.
class _Actions extends StatelessWidget {
  const new({this.onQuickExpense, this.onEditBalance});

  final VoidCallback? onQuickExpense;
  final VoidCallback? onEditBalance;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      if (onQuickExpense != null)
        Expanded(
          child: _Action(
            label: 'خصم سريع',
            icon: ZadIcons.add,
            emphasized: true,
            onTap: onQuickExpense!,
          ),
        ),
      if (onQuickExpense != null && onEditBalance != null)
        const SizedBox(width: ZadSpacing.sm),
      if (onEditBalance != null)
        Expanded(
          child: _Action(
            label: 'تعديل الميزانية',
            icon: ZadIcons.edit,
            emphasized: false,
            onTap: onEditBalance!,
          ),
        ),
    ],
  );
}

class _Action extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.emphasized,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadPressable(
    onPressed: onTap,
    semanticLabel: label,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasized ? 0.20 : 0.08),
        borderRadius: BorderRadius.circular(ZadRadii.chip + 2),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Figure extends StatefulWidget {
  const new({
    required this.amount,
    required this.currency,
    this.isConfirmed = true,
  });

  final double amount;
  final String currency;

  /// The server has confirmed this figure. When it has not — read from the
  /// cache, or a local write still queued — the figure says "≈" instead of
  /// wearing the tick, as Kotlin's does for a figure it is unsure of.
  final bool isConfirmed;

  @override
  State<_Figure> createState() => _FigureState();
}

class _FigureState extends State<_Figure> {
  /// Where the count starts.
  ///
  /// On first build this is the amount itself, so nothing animates: the figure
  /// is drawn, finished, in the first frame. Counting up from zero every time
  /// the screen opens would undo the point of reading it from the cache — the
  /// user would be watching a number arrive that the device already had.
  ///
  /// It only moves when the value does: a refresh landing, or a queued expense
  /// being subtracted. That is a change worth showing.
  late double _from = widget.amount;

  @override
  void didUpdateWidget(_Figure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) _from = oldWidget.amount;
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from, end: widget.amount),
      duration: _from == widget.amount ? Duration.zero : ZadDuration.count,
      curve: ZadCurves.standard,
      builder: (context, value, _) {
        // The figure is masked with a white→mint gradient so a number this
        // large
        // has some depth without introducing a second colour.
        final figure = ShaderMask(
          shaderCallback: (bounds) => ZadColors.heroFigure.createShader(bounds),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                    '${widget.isConfirmed ? '' : '≈ '}${_money(value)}',
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
        if (!widget.isConfirmed) return figure;
        // Outside the mask, so the tick keeps its own mint.
        return Row(
          children: <Widget>[
            Flexible(child: figure),
            const SizedBox(width: ZadSpacing.sm),
            const Icon(
              ZadIcons.selected,
              size: 20,
              color: ZadColors.confirmedTick,
            ),
          ],
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
                        ? <Color>[
                            ZadColors.mustardOchre,
                            const Color(0xFFE9A844),
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
