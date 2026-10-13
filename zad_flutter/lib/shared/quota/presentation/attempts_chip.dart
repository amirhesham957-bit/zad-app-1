/// «طاقة زاد»: the balance on the chat's bar, and the sheet behind it.
///
/// The chip is the one number the customer needs: how many attempts are left.
/// Tapping it says what each request costs, when the free 5 come back, and
/// offers the way out — a plan with no ads. The «شاهد وخد» button joins it
/// once the ads SDK is in the app; until then nothing is shown that would do
/// nothing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

/// The chip. Draws nothing until there is a real balance to show.
class AttemptsChip extends ConsumerWidget {
  /// Creates the chip.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(attemptsBalanceProvider).value;
    if (balance == null) return const SizedBox.shrink();
    final low = balance.isLow;
    final fg = low ? ZadColors.mustardOchre : ZadColors.forestEmerald;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: ZadSpacing.xs),
      child: Semantics(
        button: true,
        label: 'رصيدك ${attemptsLabel(balance.left)}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            child: Material(
              color: low
                  ? ZadColors.mustardOchre.withValues(alpha: .14)
                  : ZadColors.mint100,
              shape: const StadiumBorder(),
              child: InkWell(
                key: const ValueKey<String>('attempts-chip'),
                customBorder: const StadiumBorder(),
                onTap: () => showAttemptsSheet(
                  context,
                  balance,
                  ref.read(accountTimeZoneProvider),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.md,
                    vertical: ZadSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(ZadIcons.bill, size: 18, color: fg),
                      const SizedBox(width: ZadSpacing.xs),
                      Text(
                        arabicDigits(balance.left),
                        style: ZadType.labelLarge.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet: the balance, what things cost, when it refills, and the plans.
Future<void> showAttemptsSheet(
  BuildContext context,
  AttemptsBalance balance,
  String zone,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  // Scrolls instead of overflowing on a short phone or at large text.
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.gutter,
          0,
          ZadSpacing.gutter,
          ZadSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'طاقة زاد',
              style: ZadType.titleMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              'معاك ${attemptsLabel(balance.left)}',
              style: ZadType.headlineMedium.copyWith(
                color: ZadColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              refillLine(balance, DateTime.now(), zone),
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.lg),
            const _CostRow(label: 'تسجيل مصروف أو دخل', cost: 'مجاني'),
            _CostRow(
              label: 'رسالة شات',
              cost: attemptsLabel(AttemptCosts.chat),
            ),
            _CostRow(
              label: 'مسح فاتورة أو صورة',
              cost: attemptsLabel(AttemptCosts.scan),
            ),
            _CostRow(
              label: 'تحليل عميق أو خطة',
              cost: attemptsLabel(AttemptCosts.brain),
            ),
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              key: const ValueKey<String>('attempts-subscribe'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(ZadScreens.showPaywallScreen(context));
              },
              child: Text(
                balance.isFree ? 'اشترك من غير إعلانات' : 'شوف الباقات',
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _CostRow extends StatelessWidget {
  const new({required this.label, required this.cost});

  final String label;
  final String cost;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZadSpacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: ZadType.bodyMedium.copyWith(color: ZadColors.ink),
          ),
        ),
        Text(
          cost,
          style: ZadType.labelLarge.copyWith(
            color: ZadColors.forestEmerald,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// When the balance comes back, on the account's clock:
/// «بيرجع ٥ الساعة ٦:٣٠ م»، «بيرجع ٥ بكرة الساعة ١:١٥ ص»، or for a plan
/// «باقتك الأساسية — بتتجدد يوم ١٢ نوفمبر».
String refillLine(AttemptsBalance b, DateTime now, String zone) {
  final next = b.nextRefillAt;
  if (!b.isFree) {
    if (next == null) return 'باقتك ${b.planName}';
    final at = _inZone(next, zone);
    final day = '${arabicDigits(at.day)} ${_months[at.month - 1]}';
    return 'باقتك ${b.planName} — بتتجدد يوم $day';
  }
  if (b.cycleLeft >= b.perCycle) return 'رصيدك كامل';
  if (next == null || !next.isAfter(now)) return 'رصيدك بيرجع دلوقتي';
  final at = _inZone(next, zone);
  final today = _inZone(now, zone);
  final sameDay =
      at.year == today.year && at.month == today.month && at.day == today.day;
  final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final mm = '${arabicDigits(at.minute ~/ 10)}${arabicDigits(at.minute % 10)}';
  final clock = '${arabicDigits(h12)}:$mm ${at.hour < 12 ? 'ص' : 'م'}';
  final when = sameDay ? 'الساعة $clock' : 'بكرة الساعة $clock';
  return 'بيرجع ${arabicDigits(b.perCycle)} $when';
}

DateTime _inZone(DateTime t, String zone) {
  try {
    return tz.TZDateTime.from(t.toUtc(), tz.getLocation(zone));
  } on Object {
    return t.toLocal();
  }
}

const List<String> _months = <String>[
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
