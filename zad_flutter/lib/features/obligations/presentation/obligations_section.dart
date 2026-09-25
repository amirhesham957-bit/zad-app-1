/// Obligations on the budget screen — Kotlin's total strip, its
/// `ObligationCard`s, `AddEditObligationDialog` and the delete confirmation.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:zad/core/money/money.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/obligations/application/obligations_controller.dart';
import 'package:zad/features/obligations/domain/obligation.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// The strip, then one card per obligation, or the empty state.
class ObligationsSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(obligationsControllerProvider);
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ZadSpacing.lg + 2,
            ZadSpacing.sm,
            ZadSpacing.sm,
            ZadSpacing.sm,
          ),
          decoration: ShapeDecoration(
            color: ZadColors.surface,
            shape: zadSquircle(ZadRadii.cardLarge),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'إجمالي الالتزامات',
                  style: ZadType.labelLarge.copyWith(color: ZadColors.slate),
                ),
              ),
              Text(
                '${_money(view.total)} $currency'.trim(),
                style: ZadType.titleMedium.copyWith(
                  color: ZadColors.mustardOchre,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => unawaited(showObligationSheet(context)),
                tooltip: 'إضافة التزام',
                icon: const Icon(ZadIcons.add, color: ZadColors.mustardOchre),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZadSpacing.md),
        if (view.items.isEmpty)
          const ZadEmptyState(
            icon: ZadIcons.obligation,
            title: 'لا توجد التزامات',
            message: 'الأقساط والفواتير الثابتة هتظهر هنا أول ما تتسجل',
          )
        else
          for (final o in view.items) ...<Widget>[
            ObligationCard(
              obligation: o,
              today: view.today,
              currency: currency,
            ),
            const SizedBox(height: ZadSpacing.md),
          ],
      ],
    );
  }
}

/// One obligation: name, amount, delete; when it is due and its status; a
/// bar filling as the day approaches. A tap edits it.
class ObligationCard extends ConsumerWidget {
  /// Creates the card.
  const new({
    required this.obligation,
    required this.today,
    required this.currency,
    super.key,
  });

  /// The row.
  final Obligation obligation;

  /// Today in the account's zone.
  final DateTime today;

  /// The account's currency.
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = obligationStanding(obligation, today);
    final color = switch (s.status) {
      ObligationStatus.paid => ZadColors.forestEmerald,
      ObligationStatus.pending => ZadColors.terracottaRust,
      ObligationStatus.scheduled => ZadColors.mustardOchre,
    };
    final when = s.daysUntil == null
        ? obligation.recurrence.label
        : 'بعد ${s.daysUntil} يوم';
    return ZadPressable(
      onPressed: () => unawaited(showObligationSheet(context, obligation)),
      semanticLabel: obligation.title,
      child: Container(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: ZadColors.shadowSpot,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    obligation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZadType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
                Text(
                  '${_money(obligation.amount)} $currency'.trim(),
                  style: ZadType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      unawaited(_confirmDelete(context, ref, obligation)),
                  tooltip: 'حذف',
                  icon: const Icon(
                    ZadIcons.delete,
                    size: 18,
                    color: ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$when · ${obligation.kind.label}',
                    maxLines: 1,
                    style: ZadType.labelMedium.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ZadColors.forestEmerald.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(ZadRadii.pill),
                  ),
                  child: Text(
                    s.status.label,
                    style: ZadType.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(ZadRadii.pill),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 6,
                color: color,
                backgroundColor: const Color(0xFFF1F4F3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Obligation o,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('حذف'),
      content: Text('حذف «${o.title}» من قائمة الالتزامات؟'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ZadColors.terracottaRust,
          ),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(obligationsControllerProvider.notifier).remove(o);
  }
}

/// Opens the add sheet, or the edit sheet for [obligation].
Future<void> showObligationSheet(
  BuildContext context, [
  Obligation? obligation,
]) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => ObligationSheet(obligation: obligation),
);

/// The form.
class ObligationSheet extends ConsumerStatefulWidget {
  /// Creates the form; editing when [obligation] is given.
  const new({this.obligation, super.key});

  /// The row being edited, or null for a new one.
  final Obligation? obligation;

  @override
  ConsumerState<ObligationSheet> createState() => _ObligationSheetState();
}

class _ObligationSheetState extends ConsumerState<ObligationSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.obligation?.title ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: switch (widget.obligation?.amount) {
      final double a =>
        a == a.roundToDouble() ? a.toStringAsFixed(0) : a.asMoney.toString(),
      null => '',
    },
  );
  late final TextEditingController _day = TextEditingController(
    text: widget.obligation?.dueDay?.toString() ?? '',
  );
  late ObligationKind _kind = widget.obligation?.kind ?? ObligationKind.rent;
  late Recurrence _recurrence =
      widget.obligation?.recurrence ?? Recurrence.monthly;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  double? get _parsed => parseMoneyInput(_amount.text);

  /// 1–31, or null when blank. Anything else is not a day.
  int? get _dueDay {
    final d = int.tryParse(_day.text.trim());
    return d != null && d >= 1 && d <= 31 ? d : null;
  }

  bool get _dayOk => _day.text.trim().isEmpty || _dueDay != null;

  bool get _canSave =>
      _title.text.trim().isNotEmpty && _parsed != null && _dayOk;

  Future<void> _save() async {
    final amount = _parsed;
    if (!_canSave || amount == null) return;
    final controller = ref.read(obligationsControllerProvider.notifier);
    final editing = widget.obligation;
    if (editing == null) {
      await controller.add(
        title: _title.text,
        amount: amount,
        kind: _kind,
        recurrence: _recurrence,
        dueDay: _dueDay,
      );
    } else {
      await controller.save(
        editing.copyWith(
          title: _title.text.trim(),
          amount: amount,
          kind: _kind,
          recurrence: _recurrence,
          dueDay: _dueDay,
          clearDueDay: _dueDay == null,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ZadSpacing.xl,
          0,
          ZadSpacing.xl,
          ZadSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.obligation == null
                  ? 'إضافة التزام جديد'
                  : 'تعديل الالتزام',
              style: ZadType.titleMedium,
            ),
            const SizedBox(height: ZadSpacing.lg),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'اسم الالتزام (إيجار، كهرباء...)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: currency.isEmpty ? 'المبلغ' : 'المبلغ ($currency)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _day,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: 'يوم الاستحقاق الشهري (1-31)',
                errorText: _dayOk ? null : 'من 1 لـ 31',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'النوع',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final k in ObligationKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'التكرار',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                // A one-off needs a date this form does not ask for; Kotlin's
                // form offers it anyway and the row then has no due date at
                // all. Kept, as the brain can still read it.
                for (final r in Recurrence.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: _recurrence == r,
                    onSelected: (_) => setState(() => _recurrence = r),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
