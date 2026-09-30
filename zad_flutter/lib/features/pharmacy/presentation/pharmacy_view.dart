/// The pharmacy — Kotlin's `PharmacyScreen`: adherence and monthly cost,
/// the counts, the expired warning and the expiry tracker, today's doses,
/// and each medicine's card with take, refill, "فاضل قد إيه فعلاً؟" and
/// delete; the add form and the add-by-talking sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/components/zad_field_dialog.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/family/application/family_controller.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/dose_time.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

String _money(double v) => NumberFormat('#,##0.##', 'en').format(v);

/// Kotlin's categories and units — stored values, kept Arabic.
const List<String> kMedicineCategories = <String>[
  'عام',
  'مسكن',
  'مضاد حيوي',
  'فيتامين',
  'مزمن',
];

/// Kotlin's units.
const List<String> kMedicineUnits = <String>[
  'حبة',
  'قرص',
  'كبسولة',
  'مل',
  'بخاخ',
  'نقطة',
  'كريم',
  'كيس',
  'أمبول',
  'علبة',
];

/// Kotlin's `suggestDoseTimes`: the doses spread over 08:00–22:00.
String suggestDoseTimes(int count) {
  if (count <= 0) return '';
  if (count == 1) return '09:00';
  const start = 8 * 60;
  const end = 22 * 60;
  final step = (end - start) ~/ (count - 1);
  String two(int n) => n.toString().padLeft(2, '0');
  return <String>[
    for (var i = 0; i < count; i++)
      '${two((start + step * i) ~/ 60)}:${two((start + step * i) % 60)}',
  ].join(', ');
}

/// Kotlin's monthly cost: what the pharmacy took from the budget this
/// period, or the boxes' prices added up, whichever is more.
double pharmacyMonthlyCost(
  Iterable<Medicine> medicines,
  Iterable<ZadTransaction> periodRows,
) {
  final boxes = medicines.fold<double>(0, (s, m) => s + m.price);
  var spent = 0.0;
  for (final t in periodRows) {
    if (t.kind != TxnKind.expense) continue;
    final c = t.category;
    if (c == 'الرعاية الصحية' ||
        c == 'صيدلية' ||
        c == 'أدوية' ||
        t.sourceType == 'pharmacy') {
      spent += t.amount;
    }
  }
  return spent > boxes ? spent : boxes;
}

/// The pharmacy.
class PharmacyView extends ConsumerWidget {
  /// Creates the view.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pharmacyControllerProvider);
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final now = ref.read(nowProvider)();
    final today = DateTime.utc(now.year, now.month, now.day);
    int? daysTo(Medicine m) => m.expiryDate?.difference(today).inDays;

    final medicines = <Medicine>[...view.medicines]
      ..sort((a, b) {
        final da = daysTo(a);
        final db = daysTo(b);
        final ea = da != null && da < 0 ? 0 : 1;
        final eb = db != null && db < 0 ? 0 : 1;
        if (ea != eb) return ea.compareTo(eb);
        return (da ?? 1 << 30).compareTo(db ?? 1 << 30);
      });
    final expiringSoon = <Medicine>[
      for (final m in medicines)
        if ((daysTo(m) ?? -1) >= 0 && daysTo(m)! <= 30) m,
    ];
    final expired = medicines.where((m) => (daysTo(m) ?? 0) < 0).length;
    final low = medicines
        .where(
          (m) =>
              m.isOutOfStock ||
              m.isRunningOut ||
              (m.daysOfSupplyLeft ?? 99) <= 5,
        )
        .length;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final cost = pharmacyMonthlyCost(
      medicines,
      ref.watch(transactionsControllerProvider).rows,
    );

    final familyView = ref.watch(pharmacyFamilyViewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Kotlin: one button, and none over the family view.
      floatingActionButton: familyView
          ? null
          : FloatingActionButton(
              heroTag: 'pharmacy-add',
              onPressed: () => unawaited(showAddMedicineSheet(context)),
              tooltip: 'إضافة',
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ZadSpacing.gutter),
          children: <Widget>[
            const FamilyPharmacyToggleRow(),
            if (familyView)
              const PharmacyFamilyBody()
            else ...<Widget>[
              ExactAlarmHint(
                hasScheduledDoses: medicines.any((m) => m.doseTimes.isNotEmpty),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      label: 'الالتزام بالجرعات',
                      value: view.adherence == null
                          ? 'في انتظار أول جرعة'
                          : '${view.adherence}%',
                      color: switch (view.adherence) {
                        null => ZadColors.inkMuted,
                        final a when a >= 80 => ZadColors.green600,
                        final a when a >= 50 => ZadColors.mustardOchre,
                        _ => ZadColors.terracottaRust,
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      label: 'التكلفة الشهرية',
                      value: '${_money(cost)} $currency'.trim(),
                      color: ZadColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: ZadSpacing.lg,
                runSpacing: ZadSpacing.xs,
                children: <Widget>[
                  _Count(n: medicines.length, label: 'إجمالي الأدوية'),
                  _Count(n: expiringSoon.length, label: 'قرب الانتهاء'),
                  _Count(n: low, label: 'مخزون منخفض'),
                ],
              ),
              if (expired > 0) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                _Banner(
                  text: '$expired دواء منتهي الصلاحية — تخلص منه بأمان',
                  color: ZadColors.terracottaRust,
                ),
              ],
              if (expiringSoon.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.md),
                const Text(
                  'قرب الانتهاء — تخلص منها بأمان',
                  style: ZadType.titleSmall,
                ),
                const SizedBox(height: ZadSpacing.sm),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: expiringSoon.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final m = expiringSoon[i];
                      final d = daysTo(m)!;
                      final c = d <= 7
                          ? ZadColors.terracottaRust
                          : ZadColors.mustardOchre;
                      return Container(
                        width: 150,
                        padding: const EdgeInsets.all(ZadSpacing.md),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(ZadRadii.card),
                          border: Border.all(color: c.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZadType.titleSmall,
                            ),
                            Text(
                              'تنتهي خلال $d يوم',
                              style: ZadType.labelSmall.copyWith(color: c),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (view.today.isNotEmpty) ...<Widget>[
                const SizedBox(height: ZadSpacing.lg),
                Text(
                  'جرعات النهارده',
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                for (final slot in view.today) ...<Widget>[
                  _DoseRow(slot: slot),
                  const SizedBox(height: ZadSpacing.sm),
                ],
              ],
              const SizedBox(height: ZadSpacing.lg),
              if (medicines.isEmpty)
                ZadEmptyState(
                  icon: ZadIcons.pharmacy,
                  title: view.error != null
                      ? 'مقدرتش أجيب الأدوية'
                      : 'لا توجد أدوية مسجلة بعد',
                  message: view.error != null
                      ? 'اسحب لتحت نجرب تاني.'
                      : 'ضيفه بالزرار، أو قول لزاد: "باخد كونكور قرص الصبح '
                            'وبالليل" وهو يسجّله بمواعيده.',
                  tone: view.error != null
                      ? ZadEmptyTone.problem
                      : ZadEmptyTone.calm,
                )
              else ...<Widget>[
                Text(
                  'الأدوية',
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
                const SizedBox(height: ZadSpacing.sm),
                for (final medicine in medicines) ...<Widget>[
                  _MedicineCard(
                    medicine: medicine,
                    daysToExpiry: daysTo(medicine),
                  ),
                  const SizedBox(height: ZadSpacing.md),
                ],
              ],
              const SizedBox(height: 140),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => ZadCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
        ),
        const SizedBox(height: ZadSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: ZadType.titleLarge.copyWith(color: color)),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const new({required this.n, required this.label});

  final int n;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        '$n',
        style: ZadType.titleSmall.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: ZadSpacing.xs),
      Text(label, style: ZadType.labelMedium.copyWith(color: ZadColors.slate)),
    ],
  );
}

class _Banner extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ZadSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Row(
      children: <Widget>[
        Icon(ZadIcons.failed, size: 18, color: color),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: ZadType.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DoseRow extends ConsumerWidget {
  const new({required this.slot});

  final DoseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final now = ref.read(nowProvider)();
    final state = slot.stateAt(now);
    final snoozed = controller.isSnoozed(slot);

    final (accent, status) = switch (state) {
      DoseState.taken => (ZadColors.green600, 'اتاخدت'),
      DoseState.due => (ZadColors.mustardOchre, 'وقتها دلوقتي'),
      DoseState.missed => (ZadColors.terracottaRust, 'فاتت'),
      DoseState.upcoming => (ZadColors.inkMuted, 'جاية'),
    };

    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              // The account's civil time, not the device's. A customer
              // travelling sees the same "08:00" the server reminds them at.
              _clock(slot.scheduledAt, ref.read(accountTimeZoneProvider)),
              style: ZadType.figure(16).copyWith(color: ZadColors.ink),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(slot.medicine.name, style: ZadType.titleSmall),
                Text(
                  snoozed ? 'اتأجلت شوية' : status,
                  style: ZadType.labelSmall.copyWith(color: accent),
                ),
              ],
            ),
          ),
          if (state == DoseState.due || state == DoseState.missed) ...<Widget>[
            if (!snoozed)
              TextButton(
                onPressed: () => unawaited(controller.snooze(slot)),
                child: const Text('بعدين'),
              ),
            FilledButton(
              onPressed: () {
                unawaited(HapticFeedback.mediumImpact());
                unawaited(controller.take(slot));
              },
              child: const Text('خدته'),
            ),
          ] else if (state == DoseState.taken)
            const Icon(ZadIcons.synced, color: ZadColors.green600),
        ],
      ),
    );
  }

  static String _clock(DateTime instant, String zone) {
    final local = tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zone));
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Kotlin's `PharmacyItemCard`: a status stripe, the name and dose note, the
/// schedule and who it is for, the badges (expiry or stock, days of supply
/// or "الكمية محتاجة تأكيد"), and the actions.
class _MedicineCard extends ConsumerWidget {
  const new({required this.medicine, required this.daysToExpiry});

  final Medicine medicine;
  final int? daysToExpiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final d = daysToExpiry;
    final expired = d != null && d < 0;
    final expiringSoon = d != null && d >= 0 && d <= 30;
    final supply = medicine.daysOfSupplyLeft;
    final remaining = medicine.remainingQuantity ?? 0;
    final lowStock = medicine.isOutOfStock || (supply ?? 99) <= 5;
    final status = expired || remaining <= 0 || (supply != null && supply <= 3)
        ? ZadColors.terracottaRust
        : lowStock || expiringSoon
        ? ZadColors.mustardOchre
        : ZadColors.green600;
    final member =
        ref
            .watch(familyControllerProvider)
            .family
            ?.members
            .where((m) => m.id == medicine.familyMemberId)
            .firstOrNull
            ?.alias ??
        (medicine.forPerson == null ? null : 'لـ${medicine.forPerson}');
    final badge = expired
        ? 'منتهي منذ ${-d} يوم'
        : expiringSoon
        ? 'تنتهي خلال $d يوم'
        : 'متبقي $remaining ${medicine.unit ?? ''}'.trim();
    final invalid =
        medicine.hasUnreadableDoseTime || medicine.serverSaysInvalidDoseTime;
    final dosage = medicine.dosage;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: ZadColors.surface,
        shape: zadSquircle(ZadRadii.card),
        shadows: <BoxShadow>[
          BoxShadow(
            color: status.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 4, color: status),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(ZadSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: ZadColors.terracottaRust.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(
                              ZadIcons.pharmacy,
                              size: 20,
                              color: ZadColors.terracottaRust,
                            ),
                          ),
                        ),
                        const SizedBox(width: ZadSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                medicine.name,
                                style: ZadType.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (dosage != null && dosage.trim().isNotEmpty)
                                Text(
                                  dosage,
                                  style: ZadType.labelSmall.copyWith(
                                    color: ZadColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              unawaited(_confirmDelete(context, ref, medicine)),
                          tooltip: 'حذف',
                          icon: Icon(
                            ZadIcons.delete,
                            size: 18,
                            color: ZadColors.terracottaRust,
                          ),
                        ),
                      ],
                    ),
                    if (medicine.doseTimes.isNotEmpty || member != null)
                      Padding(
                        padding: const EdgeInsets.only(top: ZadSpacing.xs),
                        child: Text(
                          <String>[
                            if (medicine.doseTimes.isNotEmpty)
                              medicine.doseTimes
                                  .map((t) => t.wireName)
                                  .join(' · '),
                            ?member,
                          ].join('   '),
                          style: ZadType.labelSmall.copyWith(
                            color: ZadColors.inkMuted,
                          ),
                        ),
                      ),
                    if (invalid)
                      Padding(
                        padding: const EdgeInsets.only(top: ZadSpacing.xs),
                        child: Text(
                          'وقت جرعة مش مفهوم — عدّله',
                          style: ZadType.labelSmall.copyWith(
                            color: ZadColors.terracottaRust,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _Badge(text: badge, color: status),
                        if (!expired && supply != null)
                          _Badge(
                            text: 'يكفي $supply يوم',
                            color: ZadColors.inkMuted,
                          )
                        else if (!expired &&
                            ((dosage?.isNotEmpty ?? false) ||
                                medicine.doseTimes.isNotEmpty))
                          InkWell(
                            onTap: () => unawaited(
                              _showConfirmQuantity(context, ref, medicine),
                            ),
                            child: _Badge(
                              text: 'الكمية محتاجة تأكيد',
                              color: ZadColors.mustardOchre,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: ZadSpacing.sm),
                    Wrap(
                      spacing: ZadSpacing.sm,
                      runSpacing: ZadSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (remaining > 0 && medicine.doseTimes.isEmpty)
                          OutlinedButton(
                            onPressed: () {
                              unawaited(HapticFeedback.mediumImpact());
                              unawaited(controller.takeNow(medicine));
                            },
                            child: const Text('تناول جرعة'),
                          ),
                        FilledButton.icon(
                          onPressed: () =>
                              unawaited(_showRefill(context, ref, medicine)),
                          icon: const Icon(ZadIcons.retry, size: 14),
                          label: const Text('تجديد الطلب'),
                        ),
                        TextButton(
                          onPressed: () => unawaited(
                            _showConfirmQuantity(context, ref, medicine),
                          ),
                          child: const Text('فاضل قد إيه فعلاً؟'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: ZadType.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('حذف'),
      content: Text('حذف «${medicine.name}» من الصيدلية؟'),
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
    await ref.read(pharmacyControllerProvider.notifier).remove(medicine);
  }
}

/// Kotlin's `ConfirmQuantityDialog`: the counted stock, and how many units
/// one dose is — without the second the days of supply are a guess.
Future<void> _showConfirmQuantity(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  final unit = medicine.unit ?? 'حبة';
  final result = await showFieldDialog<(int, double?)>(
    context: context,
    initial: <String>[
      '${medicine.remainingQuantity ?? 0}',
      if (!medicine.unitsPerDoseKnown)
        ''
      else if (medicine.unitsPerDose == medicine.unitsPerDose.roundToDouble())
        medicine.unitsPerDose.toStringAsFixed(0)
      else
        '${medicine.unitsPerDose}',
    ],
    builder: (c, fields) => AlertDialog(
      title: const Text('فاضل قد إيه فعلاً؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${medicine.name} — الكمية الحالية المسجلة: '
            '${medicine.remainingQuantity ?? 0} $unit',
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: fields[0],
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: unit),
          ),
          const SizedBox(height: ZadSpacing.md),
          TextField(
            controller: fields[1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'الجرعة الواحدة كام $unit؟',
              helperText: 'من غير الرقم ده مقدرش أحسب المخزون هيكفي كام يوم',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final raw = fields[0].text.trim();
            final n = raw == '0' || raw == '٠'
                ? 0
                : parseMoneyInput(raw)?.round();
            if (n == null) return;
            Navigator.of(c).pop((n, parseMoneyInput(fields[1].text)));
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  if (result == null) return;
  await ref
      .read(pharmacyControllerProvider.notifier)
      .confirmQuantity(medicine, result.$1, unitsPerDose: result.$2);
}

/// Kotlin's `RefillPharmacyItemDialog`: how many more, and a new price and
/// expiry if the box changed.
Future<void> _showRefill(
  BuildContext context,
  WidgetRef ref,
  Medicine medicine,
) async {
  DateTime? expiry;
  final unit = medicine.unit ?? 'حبة';
  final result = await showFieldDialog<(int, double?)>(
    context: context,
    initial: <String>[
      '',
      if (medicine.price > 0) medicine.price.toStringAsFixed(0) else '',
    ],
    builder: (c, fields) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text('تجديد طلب ${medicine.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: fields[0],
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: 'الكمية المضافة ($unit)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: fields[1],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'السعر'),
            ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: c,
                  initialDate: now.add(const Duration(days: 365)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(
                    () => expiry = DateTime.utc(
                      picked.year,
                      picked.month,
                      picked.day,
                    ),
                  );
                }
              },
              icon: const Icon(ZadIcons.duration, size: 16),
              label: Text(
                expiry == null
                    ? 'تاريخ الانتهاء'
                    : DateFormat('d MMMM y', 'ar').format(expiry!),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: (parseMoneyInput(fields[0].text)?.round() ?? 0) > 0
                ? () => Navigator.of(c).pop((
                    parseMoneyInput(fields[0].text)!.round(),
                    parseMoneyInput(fields[1].text),
                  ))
                : null,
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  final (count, newPrice) = result;
  await ref
      .read(pharmacyControllerProvider.notifier)
      .refill(
        medicine,
        added: count,
        price: newPrice != medicine.price ? newPrice : null,
        expiryDate: expiry,
      );
}

/// Opens Kotlin's add form, filled in from [scanned] when a box was read.
Future<void> showAddMedicineSheet(
  BuildContext context, {
  ScannedMedicine? scanned,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: ZadColors.surface,
  shape: zadSquircle(ZadRadii.sheet),
  builder: (_) => _AddMedicineSheet(scanned: scanned),
);

class _AddMedicineSheet extends ConsumerStatefulWidget {
  const new({this.scanned});

  final ScannedMedicine? scanned;

  @override
  ConsumerState<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends ConsumerState<_AddMedicineSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '10');
  final TextEditingController _daily = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _ingredient = TextEditingController();
  final TextEditingController _dosage = TextEditingController();
  final TextEditingController _forPerson = TextEditingController();
  String _unit = kMedicineUnits[1];
  String _category = kMedicineCategories.first;
  final List<String> _times = <String>[];
  DateTime? _expiry;
  bool _recurring = false;
  String? _member;
  bool _extras = false;

  static const List<(String, String)> _presets = <(String, String)>[
    ('08:00', '🌅 صباحاً'),
    ('14:00', '☀️ ظهراً'),
    ('20:00', '🌙 مساءً'),
    ('23:00', '🛌 قبل النوم'),
  ];

  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    final s = widget.scanned;
    if (s != null) _fill(s);
  }

  /// Kotlin's `AddPharmacyItemDialog` camera button: a photo of the box,
  /// `analyze_medicine_image`, and the form filled with what it read.
  Future<void> _scanBox() async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || _scanning) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final image = await ref
        .read(receiptCameraProvider)
        .capture(ReceiptImageSource.camera);
    if (image == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final result = await ref
          .read(visionScannerProvider)
          .medicine(userId: userId, image: image);
      if (!mounted) return;
      if (result != null && result.name.trim().isNotEmpty) {
        setState(() => _fill(result));
        messenger?.showSnackBar(
          const SnackBar(content: Text('تم استخراج بيانات الدواء بنجاح')),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح'),
          ),
        );
      }
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح'),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _fill(ScannedMedicine s) {
    _name.text = s.name;
    _qty.text = '${s.quantity}';
    _daily.text = '${s.dailyDoseCount < 1 ? 1 : s.dailyDoseCount}';
    _ingredient.text = s.activeIngredient?.trim() ?? '';
    _dosage.text = s.dosage?.trim() ?? '';
    _unit = s.unit;
    if (kMedicineCategories.contains(s.category)) _category = s.category;
    _times
      ..clear()
      ..addAll(scannedDoseTimes(s.doseTimes));
    _expiry = s.expiryDate;
    // What was read off the box should be in view, not folded away.
    _extras = _ingredient.text.isNotEmpty || _dosage.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _qty,
      _daily,
      _price,
      _ingredient,
      _dosage,
      _forPerson,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _dailyCount => int.tryParse(_daily.text.trim()) ?? 1;

  String get _suggested => suggestDoseTimes(_dailyCount);

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (int.tryParse(_qty.text.trim()) ?? -1) >= 0;

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'اختر ميعاد الجرعة',
    );
    if (picked == null) return;
    final t =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    if (!_times.contains(t)) setState(() => _times.add(t));
  }

  Future<void> _save() async {
    if (!_canSave) return;
    // Kotlin fills an empty schedule with times spread over the day.
    final times = _times.isEmpty
        ? suggestDoseTimes(_dailyCount)
        : (_times..sort()).join(', ');
    await ref
        .read(pharmacyControllerProvider.notifier)
        .add(
          name: _name.text,
          quantity: int.parse(_qty.text.trim()),
          unit: _unit,
          dailyDoseCount: _dailyCount,
          doseTimes: times.isEmpty ? null : times.replaceAll(' ', ''),
          expiryDate: _expiry,
          price: parseMoneyInput(_price.text) ?? 0,
          activeIngredient: _ingredient.text.trim().isEmpty
              ? null
              : _ingredient.text.trim(),
          dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
          category: _category,
          isRecurring: _recurring,
          familyMemberId: _member,
          forPerson: _forPerson.text.trim().isEmpty
              ? null
              : _forPerson.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(familyControllerProvider).family?.members ?? const [];
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.scanned == null ? 'إضافة دواء' : 'راجع الدواء',
              style: ZadType.titleMedium,
            ),
            if (widget.scanned != null) ...<Widget>[
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'قريت ده من العلبة — عدّل أي حاجة غلط قبل ما تحفظ.',
                style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
              ),
            ],
            const SizedBox(height: ZadSpacing.lg),
            OutlinedButton(
              onPressed: _scanning ? null : () => unawaited(_scanBox()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_scanning) ...<Widget>[
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'جاري قراءة علبة الدواء بالذكاء الاصطناعي...',
                      style: ZadType.labelMedium,
                    ),
                  ] else ...<Widget>[
                    const Icon(Icons.camera_alt, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'مسح العبوة بالكاميرا',
                      style: ZadType.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: widget.scanned == null,
              decoration: const InputDecoration(labelText: 'اسم الدواء'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _forPerson,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'لمين؟ (سيبها فاضية لو ليك)',
                hintText: 'ماما، بابا، يوسف…',
                counterText: '',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الكمية المتبقية'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'الوحدة',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final u in <String>[
                  ...kMedicineUnits,
                  // A unit the box printed that the list lacks stays
                  // choosable rather than silently swapped for another.
                  if (!kMedicineUnits.contains(_unit)) _unit,
                ])
                  ChoiceChip(
                    label: Text(u),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _daily,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'جرعات اليوم'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: ZadSpacing.md),
            Text(
              'مواعيد الجرعة (اختياري)',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xs),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.xs,
              children: <Widget>[
                for (final (t, label) in _presets)
                  FilterChip(
                    label: Text(label),
                    selected: _times.contains(t),
                    onSelected: (on) =>
                        setState(() => on ? _times.add(t) : _times.remove(t)),
                  ),
                for (final t in _times.where(
                  (t) => !_presets.any((p) => p.$1 == t),
                ))
                  InputChip(
                    label: Text(t),
                    onDeleted: () => setState(() => _times.remove(t)),
                  ),
                ActionChip(
                  avatar: const Icon(ZadIcons.add, size: 16),
                  label: const Text('إضافة ميعاد'),
                  onPressed: () => unawaited(_addTime()),
                ),
              ],
            ),
            if (_times.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: ZadSpacing.xs),
                child: Text(
                  'لسه مفيش مواعيد مضافة — مقترح: '
                  '${_suggested.isEmpty ? '09:00' : _suggested}',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ),
            const SizedBox(height: ZadSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 365)),
                  firstDate: now.subtract(const Duration(days: 1)),
                  lastDate: now.add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(
                    () => _expiry = DateTime.utc(
                      picked.year,
                      picked.month,
                      picked.day,
                    ),
                  );
                }
              },
              icon: const Icon(ZadIcons.duration, size: 16),
              label: Text(
                _expiry == null
                    ? 'تاريخ الانتهاء — اضغط لاختيار التاريخ'
                    : DateFormat('d MMMM y', 'ar').format(_expiry!),
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: currency.isEmpty ? 'المبلغ' : 'المبلغ ($currency)',
              ),
            ),
            const SizedBox(height: ZadSpacing.md),
            TextButton(
              onPressed: () => setState(() => _extras = !_extras),
              child: const Text('تفاصيل إضافية (اختياري)'),
            ),
            if (_extras) ...<Widget>[
              TextField(
                controller: _ingredient,
                decoration: const InputDecoration(labelText: 'المادة الفعالة'),
              ),
              const SizedBox(height: ZadSpacing.md),
              TextField(
                controller: _dosage,
                decoration: const InputDecoration(
                  labelText: 'الجرعة (مثال: قرص كل 8 ساعات)',
                ),
              ),
              CheckboxListTile(
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v ?? false),
                title: const Text('دواء مزمن / روشتة متجددة شهرياً'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (members.length > 1)
                DropdownButtonFormField<String?>(
                  initialValue: _member,
                  decoration: const InputDecoration(
                    labelText: 'لمين في العائلة',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(child: Text('بدون')),
                    for (final m in members)
                      DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.alias),
                      ),
                  ],
                  onChanged: (v) => setState(() => _member = v),
                ),
              const SizedBox(height: ZadSpacing.md),
              Wrap(
                spacing: ZadSpacing.sm,
                children: <Widget>[
                  for (final c in kMedicineCategories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A box reading's suggested times as the form keeps them: only what the
/// server's `dose_times` regex accepts, padded, once each, in order.
List<String> scannedDoseTimes(String? raw) {
  final times = <DoseTime>[
    for (final part in (raw ?? '').split(',')) ?DoseTime.parse(part),
  ]..sort();
  return <String>{for (final t in times) t.wireName}.toList();
}
