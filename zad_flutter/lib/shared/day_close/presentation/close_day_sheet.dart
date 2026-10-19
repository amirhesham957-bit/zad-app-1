/// «اقفل يومك» (ZAD_PLAN ٣.٢): what Zad saw today, and three answers. Any of
/// them closes the day; «صرفت كاش» and «في حاجة ناقصة» then open the expense
/// form, so an amount is always typed, never guessed from a button.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/day_close/application/day_close_controller.dart';
import 'package:zad/shared/day_close/data/day_close_remote.dart';
import 'package:zad/shared/day_close/domain/close_day_line.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// What the sheet asks its opener to show once it is closed.
enum CloseDayNext {
  /// The expense form, paid in cash.
  cashExpense,

  /// The expense form.
  expense,

  /// Bank reading.
  bank,
}

/// Opens the sheet, then what the answer asked for — with the opener's
/// [context] and [ref], since the sheet's own are gone by then.
Future<void> showCloseDaySheet(BuildContext context, WidgetRef ref) async {
  final next = await showModalBottomSheet<CloseDayNext>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ZadColors.surface,
    shape: zadSquircle(ZadRadii.hero),
    builder: (_) => const CloseDaySheet(),
  );
  if (next == null || !context.mounted) return;
  switch (next) {
    case CloseDayNext.cashExpense:
      await ZadScreens.showCashExpenseSheet(context);
    case CloseDayNext.expense:
      await ZadScreens.showQuickExpenseSheet(context);
    case CloseDayNext.bank:
      await ZadScreens.openBankReading(context, ref);
  }
}

/// Today's expenses as the sheet names them, newest first.
List<SeenExpense> seenToday(
  List<ZadTransaction> rows, {
  required String zone,
  required String today,
}) {
  final seen =
      rows
          .where((t) => t.kind == TxnKind.expense)
          .where((t) => accountDayOf(zone, t.createdAt) == today)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return <SeenExpense>[
    for (final t in seen)
      (
        name: (t.merchantName?.trim().isNotEmpty ?? false)
            ? t.merchantName!.trim()
            : t.title.trim(),
        amount: t.amount,
      ),
  ];
}

/// The sheet.
class CloseDaySheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const new({super.key});

  @override
  ConsumerState<CloseDaySheet> createState() => _CloseDaySheetState();
}

class _CloseDaySheetState extends ConsumerState<CloseDaySheet> {
  DayCloseOutcome? _sending;

  Future<void> _close(DayCloseOutcome outcome) async {
    if (_sending != null) return;
    setState(() => _sending = outcome);
    final done = await ref.read(dayCloseProvider.notifier).close(outcome);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final r = done.result;
    if (!r.ok) {
      setState(() => _sending = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r.reason == 'offline'
                ? 'مفيش نت دلوقتي — اقفل يومك لما النت يرجع'
                : 'ماقدرتش أقفل يومك دلوقتي — جرّب تاني',
          ),
        ),
      );
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          closeDayThanks(already: r.already, xp: r.xp, petAte: done.petAte),
        ),
      ),
    );
    navigator.pop(switch (outcome) {
      DayCloseOutcome.cash => CloseDayNext.cashExpense,
      DayCloseOutcome.missing => CloseDayNext.expense,
      DayCloseOutcome.allGood => null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(dayCloseProvider.notifier);
    final rows = ref.watch(transactionsControllerProvider).rows;
    final currency = ref.watch(budgetControllerProvider).snapshot?.currency;
    final line = closeDayLine(
      seenToday(
        rows,
        zone: ref.watch(accountTimeZoneProvider),
        today: controller.today(),
      ),
      currency: currency,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.lg + 4,
          0,
          ZadSpacing.lg + 4,
          ZadSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('🌙 اقفل يومك', style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              line,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.ink),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              'أي إجابة بتقفل يومك، ورفيقك بياكل عشاه.',
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.lg),
            _Answer(
              label: '✅ تمام كده',
              primary: true,
              busy: _sending == DayCloseOutcome.allGood,
              onPressed: _sending == null
                  ? () => _close(DayCloseOutcome.allGood)
                  : null,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Answer(
                    label: '💵 صرفت كاش',
                    busy: _sending == DayCloseOutcome.cash,
                    onPressed: _sending == null
                        ? () => _close(DayCloseOutcome.cash)
                        : null,
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: _Answer(
                    label: '➕ في حاجة ناقصة',
                    busy: _sending == DayCloseOutcome.missing,
                    onPressed: _sending == null
                        ? () => _close(DayCloseOutcome.missing)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            TextButton(
              onPressed: _sending == null
                  ? () => Navigator.of(context).pop(CloseDayNext.bank)
                  : null,
              child: const Text('اربط البنك عشان أشوف لوحدي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZadRadii.card),
    );
    final child = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    return SizedBox(
      height: 52,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: ZadColors.green600,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(shape: shape),
              child: child,
            ),
    );
  }
}
